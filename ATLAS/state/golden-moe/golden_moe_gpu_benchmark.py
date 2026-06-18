#!/usr/bin/env python3
"""Golden MoE GPU Benchmark — Multi-scale comparison on MNIST & CIFAR-10

Compares Top-K MoE vs Golden MoE (Boltzmann T=e) vs Dense across 4 scales:
  Small:  8 experts, hidden=128
  Medium: 16 experts, hidden=256
  Large:  32 experts, hidden=512
  XL:     64 experts, hidden=1024

Uses mixed precision (torch.amp) for GPU efficiency.
Tracks accuracy, training time, GPU memory, expert utilization.
"""

import argparse
import time
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms


# ─────────────────────────────────────────
# Expert
# ─────────────────────────────────────────
class Expert(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, dropout=0.3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, output_dim),
        )

    def forward(self, x):
        return self.net(x)


# ─────────────────────────────────────────
# Gates
# ─────────────────────────────────────────
class TopKGate(nn.Module):
    def __init__(self, input_dim, n_experts, k=2):
        super().__init__()
        self.gate = nn.Linear(input_dim, n_experts)
        self.k = k

    def forward(self, x):
        scores = self.gate(x)
        topk_vals, topk_idx = scores.topk(self.k, dim=-1)
        mask = torch.zeros_like(scores)
        mask.scatter_(-1, topk_idx, 1.0)
        weights = F.softmax(scores, dim=-1) * mask
        return weights / (weights.sum(dim=-1, keepdim=True) + 1e-8)


class BoltzmannGate(nn.Module):
    def __init__(self, input_dim, n_experts, temperature=np.e, active_ratio=0.7):
        super().__init__()
        self.gate = nn.Linear(input_dim, n_experts)
        self.temperature = temperature
        self.n_active = max(1, int(n_experts * active_ratio))

    def forward(self, x):
        scores = self.gate(x) / self.temperature
        probs = F.softmax(scores, dim=-1)
        topk_vals, topk_idx = probs.topk(self.n_active, dim=-1)
        mask = torch.zeros_like(probs)
        mask.scatter_(-1, topk_idx, 1.0)
        weights = probs * mask
        return weights / (weights.sum(dim=-1, keepdim=True) + 1e-8)


# ─────────────────────────────────────────
# MoE Model
# ─────────────────────────────────────────
class MoEModel(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, n_experts=8,
                 gate_type='boltzmann', k=2, temperature=np.e,
                 active_ratio=0.7, dropout=0.3):
        super().__init__()
        self.experts = nn.ModuleList([
            Expert(input_dim, hidden_dim, output_dim, dropout)
            for _ in range(n_experts)
        ])
        self.n_experts = n_experts
        self.gate_type = gate_type

        if gate_type == 'topk':
            self.gate = TopKGate(input_dim, n_experts, k)
        elif gate_type == 'boltzmann':
            self.gate = BoltzmannGate(input_dim, n_experts, temperature, active_ratio)
        else:  # dense
            self.gate = None

        # Tracking buffers (not saved in state_dict)
        self.register_buffer('expert_usage', torch.zeros(n_experts))
        self._active_counts = []

    def forward(self, x):
        # Stack all expert outputs: (batch, n_experts, output_dim)
        expert_outputs = torch.stack([e(x) for e in self.experts], dim=1)

        if self.gate is None:  # Dense — average all experts
            output = expert_outputs.mean(dim=1)
            if self.training:
                self._active_counts.append(float(self.n_experts))
        else:
            weights = self.gate(x)  # (batch, n_experts)
            output = (weights.unsqueeze(-1) * expert_outputs).sum(dim=1)

            if self.training:
                with torch.no_grad():
                    active = (weights > 1e-6).float().sum(dim=-1).mean().item()
                    self._active_counts.append(active)
                    self.expert_usage += (weights > 1e-6).float().sum(dim=0).mean(dim=0)

        return output

    def get_metrics(self):
        total = self.expert_usage.sum().item()
        usage = self.expert_usage / max(total, 1.0)
        avg_active = np.mean(self._active_counts) if self._active_counts else 0.0
        # Count how many experts get > 1% of total usage
        utilized = (usage > 0.01).sum().item()
        return {
            'avg_active': avg_active,
            'active_ratio': avg_active / self.n_experts,
            'usage_std': usage.std().item(),
            'experts_utilized': int(utilized),
            'utilization_pct': utilized / self.n_experts * 100,
            'I_effective': 1.0 - avg_active / self.n_experts,
        }

    def reset_metrics(self):
        self.expert_usage.zero_()
        self._active_counts.clear()


# ─────────────────────────────────────────
# Training Loop (mixed precision)
# ─────────────────────────────────────────
def train_model(model, train_loader, test_loader, epochs, lr, device, use_amp=True):
    model.to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    criterion = nn.CrossEntropyLoss()

    scaler = torch.amp.GradScaler(device=device.type, enabled=use_amp)
    amp_dtype = torch.float16 if device.type == 'cuda' else torch.bfloat16

    test_accs = []
    best_acc = 0.0

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0
        n_batches = 0

        for X, y in train_loader:
            X = X.to(device, non_blocking=True).view(X.size(0), -1)
            y = y.to(device, non_blocking=True)

            optimizer.zero_grad(set_to_none=True)
            with torch.amp.autocast(device_type=device.type, dtype=amp_dtype, enabled=use_amp):
                out = model(X)
                loss = criterion(out, y)

            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()

            total_loss += loss.item()
            n_batches += 1

        scheduler.step()

        # Evaluate
        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for X, y in test_loader:
                X = X.to(device, non_blocking=True).view(X.size(0), -1)
                y = y.to(device, non_blocking=True)
                with torch.amp.autocast(device_type=device.type, dtype=amp_dtype, enabled=use_amp):
                    out = model(X)
                pred = out.argmax(dim=1)
                correct += (pred == y).sum().item()
                total += y.size(0)

        acc = correct / total
        test_accs.append(acc)
        best_acc = max(best_acc, acc)

        if (epoch + 1) % 5 == 0 or epoch == 0 or epoch == epochs - 1:
            avg_loss = total_loss / n_batches
            print(f"      Epoch {epoch+1:>3}/{epochs}: loss={avg_loss:.4f}  acc={acc*100:.2f}%  best={best_acc*100:.2f}%")

    return test_accs, best_acc


# ─────────────────────────────────────────
# GPU Memory Tracking
# ─────────────────────────────────────────
def get_gpu_memory_mb(device):
    if device.type != 'cuda':
        return 0.0
    return torch.cuda.max_memory_allocated(device) / (1024 * 1024)


def reset_gpu_memory(device):
    if device.type == 'cuda':
        torch.cuda.reset_peak_memory_stats(device)
        torch.cuda.empty_cache()


# ─────────────────────────────────────────
# Data Loading
# ─────────────────────────────────────────
def load_mnist(batch_size, num_workers=4):
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    train_data = datasets.MNIST('./data', train=True, download=True, transform=transform)
    test_data = datasets.MNIST('./data', train=False, transform=transform)
    train_loader = DataLoader(train_data, batch_size=batch_size, shuffle=True,
                              num_workers=num_workers, pin_memory=True, persistent_workers=True)
    test_loader = DataLoader(test_data, batch_size=batch_size * 2, shuffle=False,
                             num_workers=num_workers, pin_memory=True, persistent_workers=True)
    return train_loader, test_loader, 784, 'MNIST'


def load_cifar10(batch_size, num_workers=4):
    transform_train = transforms.Compose([
        transforms.RandomHorizontalFlip(),
        transforms.RandomCrop(32, padding=4),
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2470, 0.2435, 0.2616))
    ])
    transform_test = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2470, 0.2435, 0.2616))
    ])
    train_data = datasets.CIFAR10('./data', train=True, download=True, transform=transform_train)
    test_data = datasets.CIFAR10('./data', train=False, transform=transform_test)
    train_loader = DataLoader(train_data, batch_size=batch_size, shuffle=True,
                              num_workers=num_workers, pin_memory=True, persistent_workers=True)
    test_loader = DataLoader(test_data, batch_size=batch_size * 2, shuffle=False,
                             num_workers=num_workers, pin_memory=True, persistent_workers=True)
    return train_loader, test_loader, 3072, 'CIFAR-10'


# ─────────────────────────────────────────
# Scale Configurations
# ─────────────────────────────────────────
SCALES = {
    'Small':  {'n_experts': 8,  'hidden_dim': 128},
    'Medium': {'n_experts': 16, 'hidden_dim': 256},
    'Large':  {'n_experts': 32, 'hidden_dim': 512},
    'XL':     {'n_experts': 64, 'hidden_dim': 1024},
}

GATE_CONFIGS = [
    ('Top-K',      'topk',      {'k': 2}),
    ('Golden MoE', 'boltzmann', {'temperature': np.e, 'active_ratio': 0.7}),
    ('Dense',      'dense',     {}),
]


# ─────────────────────────────────────────
# Run Benchmark for One Dataset
# ─────────────────────────────────────────
def run_benchmark(dataset_name, train_loader, test_loader, input_dim, epochs,
                  batch_size, device, use_amp):
    output_dim = 10
    all_results = {}  # {(scale_name, gate_name): {...}}

    for scale_name, scale_cfg in SCALES.items():
        n_experts = scale_cfg['n_experts']
        hidden_dim = scale_cfg['hidden_dim']

        print(f"\n  {'=' * 70}")
        print(f"  Scale: {scale_name} ({n_experts} experts, hidden={hidden_dim})")
        print(f"  {'=' * 70}")

        for gate_name, gate_type, gate_kwargs in GATE_CONFIGS:
            print(f"\n    --- {gate_name} ---")

            model = MoEModel(
                input_dim, hidden_dim, output_dim,
                n_experts=n_experts, gate_type=gate_type,
                dropout=0.3, **gate_kwargs
            )
            param_count = sum(p.numel() for p in model.parameters())
            print(f"      Parameters: {param_count:,}")

            reset_gpu_memory(device)
            start_time = time.time()

            accs, best_acc = train_model(
                model, train_loader, test_loader,
                epochs=epochs, lr=1e-3, device=device, use_amp=use_amp
            )

            elapsed = time.time() - start_time
            gpu_mem = get_gpu_memory_mb(device)
            metrics = model.get_metrics()

            key = (scale_name, gate_name)
            all_results[key] = {
                'final_acc': accs[-1],
                'best_acc': best_acc,
                'time_s': elapsed,
                'gpu_mem_mb': gpu_mem,
                'params': param_count,
                'experts_utilized': metrics['experts_utilized'],
                'utilization_pct': metrics['utilization_pct'],
                'I_effective': metrics['I_effective'],
                'active_ratio': metrics['active_ratio'],
                'n_experts': n_experts,
            }

            print(f"      Final: {accs[-1]*100:.2f}%  Best: {best_acc*100:.2f}%  "
                  f"Time: {elapsed:.1f}s  GPU: {gpu_mem:.0f}MB  "
                  f"Utilized: {metrics['experts_utilized']}/{n_experts}")

            # Free memory between runs
            del model
            if device.type == 'cuda':
                torch.cuda.empty_cache()

    return all_results


# ─────────────────────────────────────────
# Reporting
# ─────────────────────────────────────────
def print_comparison_table(dataset_name, results):
    """Print a comparison table across all scales and gate types."""
    print(f"\n{'=' * 90}")
    print(f"  {dataset_name} — Full Comparison Table")
    print(f"{'=' * 90}")

    header = f"  {'Scale':<8} {'Gate':<12} {'Params':>10} {'Best%':>7} {'Final%':>7} {'Time':>7} {'GPU MB':>7} {'Util':>6} {'I_eff':>6}"
    print(header)
    print(f"  {'-' * 86}")

    for scale_name in SCALES:
        for gate_name, _, _ in GATE_CONFIGS:
            key = (scale_name, gate_name)
            r = results[key]
            print(f"  {scale_name:<8} {gate_name:<12} {r['params']:>10,} "
                  f"{r['best_acc']*100:>6.2f}% {r['final_acc']*100:>6.2f}% "
                  f"{r['time_s']:>6.1f}s {r['gpu_mem_mb']:>6.0f}M "
                  f"{r['experts_utilized']:>3}/{r['n_experts']:<3} {r['I_effective']:>5.3f}")
        print(f"  {'-' * 86}")


def print_gap_analysis(dataset_name, results):
    """Print how Golden MoE vs Top-K gap changes with scale."""
    print(f"\n{'=' * 70}")
    print(f"  {dataset_name} — Golden MoE vs Top-K Gap by Scale")
    print(f"{'=' * 70}")

    print(f"  {'Scale':<8} {'Top-K':>8} {'Golden':>8} {'Dense':>8} {'Gap(G-T)':>10} {'Bar'}")
    print(f"  {'-' * 66}")

    gaps = []
    for scale_name in SCALES:
        topk_acc = results[(scale_name, 'Top-K')]['best_acc']
        golden_acc = results[(scale_name, 'Golden MoE')]['best_acc']
        dense_acc = results[(scale_name, 'Dense')]['best_acc']
        gap = golden_acc - topk_acc
        gaps.append((scale_name, gap))

        bar_len = int(abs(gap) * 500)  # scale for visibility
        bar_char = '+' if gap > 0 else '-'
        bar = bar_char * max(1, bar_len)
        sign = '+' if gap >= 0 else ''

        print(f"  {scale_name:<8} {topk_acc*100:>7.2f}% {golden_acc*100:>7.2f}% "
              f"{dense_acc*100:>7.2f}% {sign}{gap*100:>8.2f}%  {bar}")

    print(f"\n  Gap Trend:")
    if len(gaps) >= 2:
        first_gap = gaps[0][1]
        last_gap = gaps[-1][1]
        if abs(last_gap) > abs(first_gap) and last_gap > 0:
            print(f"    -> Gap INCREASES with scale: {first_gap*100:+.2f}% -> {last_gap*100:+.2f}%")
            print(f"    -> Consistent with Hypothesis 128 (scale dependency)")
        elif abs(last_gap) < abs(first_gap):
            print(f"    -> Gap DECREASES with scale: {first_gap*100:+.2f}% -> {last_gap*100:+.2f}%")
        else:
            print(f"    -> Gap is STABLE across scales")


def print_expert_utilization(dataset_name, results):
    """Print expert utilization comparison."""
    print(f"\n{'=' * 70}")
    print(f"  {dataset_name} — Expert Utilization")
    print(f"{'=' * 70}")

    print(f"  {'Scale':<8} {'Gate':<12} {'Active':>8} {'Utilized':>10} {'I_eff':>7} {'Zone'}")
    print(f"  {'-' * 60}")

    for scale_name in SCALES:
        for gate_name, _, _ in GATE_CONFIGS:
            key = (scale_name, gate_name)
            r = results[key]
            I = r['I_effective']
            if 0.2123 <= I <= 0.500:
                zone = "Golden Zone"
            elif I < 0.2123:
                zone = "Below"
            else:
                zone = "Outside"

            active_str = f"{r['active_ratio']*100:.0f}%"
            util_str = f"{r['experts_utilized']}/{r['n_experts']}"
            print(f"  {scale_name:<8} {gate_name:<12} {active_str:>8} {util_str:>10} {I:>6.3f}  {zone}")
        print()


def print_gpu_efficiency(dataset_name, results):
    """Print accuracy per GPU-MB and accuracy per second."""
    print(f"\n{'=' * 70}")
    print(f"  {dataset_name} — GPU Efficiency")
    print(f"{'=' * 70}")

    print(f"  {'Scale':<8} {'Gate':<12} {'Acc/sec':>10} {'Acc/MB':>10} {'Best%':>7}")
    print(f"  {'-' * 52}")

    for scale_name in SCALES:
        for gate_name, _, _ in GATE_CONFIGS:
            key = (scale_name, gate_name)
            r = results[key]
            acc_per_sec = r['best_acc'] * 100 / max(r['time_s'], 0.1)
            acc_per_mb = r['best_acc'] * 100 / max(r['gpu_mem_mb'], 1.0) if r['gpu_mem_mb'] > 0 else 0
            print(f"  {scale_name:<8} {gate_name:<12} {acc_per_sec:>9.3f}  {acc_per_mb:>9.4f}  {r['best_acc']*100:>6.2f}%")
        print(f"  {'-' * 52}")


def print_final_summary(all_dataset_results):
    """Print cross-dataset summary."""
    print(f"\n{'=' * 90}")
    print(f"  FINAL SUMMARY — Golden MoE vs Top-K Gap Across Datasets and Scales")
    print(f"{'=' * 90}")

    dataset_names = list(all_dataset_results.keys())
    header = f"  {'Scale':<8}"
    for ds in dataset_names:
        header += f" {'Gap(' + ds + ')':>16}"
    print(header)
    print(f"  {'-' * (8 + 17 * len(dataset_names))}")

    for scale_name in SCALES:
        line = f"  {scale_name:<8}"
        for ds_name in dataset_names:
            results = all_dataset_results[ds_name]
            topk_acc = results[(scale_name, 'Top-K')]['best_acc']
            golden_acc = results[(scale_name, 'Golden MoE')]['best_acc']
            gap = golden_acc - topk_acc
            line += f" {gap*100:>+15.2f}%"
        print(line)

    print(f"\n  Prediction: Gap increases with scale (H128)")
    print(f"  Golden Zone: I = 1 - active_ratio, optimal near 1/e = 0.368")


# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description='Golden MoE GPU Benchmark')
    parser.add_argument('--epochs', type=int, default=20, help='Training epochs per run (default: 20)')
    parser.add_argument('--batch-size', type=int, default=256, help='Batch size (default: 256)')
    parser.add_argument('--device', type=str, default='cuda', help='Device: cuda, mps, cpu (default: cuda)')
    parser.add_argument('--no-amp', action='store_true', help='Disable mixed precision')
    parser.add_argument('--scales', type=str, default='all',
                        help='Comma-separated scales to test: Small,Medium,Large,XL or "all" (default: all)')
    parser.add_argument('--datasets', type=str, default='both',
                        help='mnist, cifar10, or both (default: both)')
    parser.add_argument('--workers', type=int, default=4, help='DataLoader workers (default: 4)')
    args = parser.parse_args()

    # Device setup
    if args.device == 'cuda' and not torch.cuda.is_available():
        print("  CUDA not available, falling back to CPU")
        device = torch.device('cpu')
    elif args.device == 'mps' and not torch.backends.mps.is_available():
        print("  MPS not available, falling back to CPU")
        device = torch.device('cpu')
    else:
        device = torch.device(args.device)

    use_amp = not args.no_amp and device.type in ('cuda', 'cpu')

    # Filter scales
    if args.scales != 'all':
        selected = [s.strip() for s in args.scales.split(',')]
        global SCALES
        SCALES = {k: v for k, v in SCALES.items() if k in selected}

    print()
    print("=" * 90)
    print("  Golden MoE GPU Benchmark — Multi-Scale Comparison")
    print("=" * 90)
    print(f"  Device:          {device}")
    if device.type == 'cuda':
        print(f"  GPU:             {torch.cuda.get_device_name(device)}")
        print(f"  GPU Memory:      {torch.cuda.get_device_properties(device).total_mem / 1024**3:.1f} GB")
    print(f"  Mixed Precision: {'ON' if use_amp else 'OFF'}")
    print(f"  Epochs:          {args.epochs}")
    print(f"  Batch Size:      {args.batch_size}")
    print(f"  Scales:          {', '.join(SCALES.keys())}")
    print(f"  Gate Types:      Top-K (K=2), Golden MoE (T=e, 70%), Dense (100%)")
    total_runs = len(SCALES) * len(GATE_CONFIGS)
    ds_count = 2 if args.datasets == 'both' else 1
    print(f"  Total Runs:      {total_runs * ds_count} ({total_runs} per dataset x {ds_count} datasets)")
    print()

    # Compile dataset loaders
    dataset_loaders = []
    if args.datasets in ('mnist', 'both'):
        dataset_loaders.append(('MNIST', load_mnist))
    if args.datasets in ('cifar10', 'both'):
        dataset_loaders.append(('CIFAR-10', load_cifar10))

    all_dataset_results = {}

    for ds_name, loader_fn in dataset_loaders:
        print(f"\n{'#' * 90}")
        print(f"  Dataset: {ds_name}")
        print(f"{'#' * 90}")

        train_loader, test_loader, input_dim, _ = loader_fn(args.batch_size, args.workers)

        results = run_benchmark(
            ds_name, train_loader, test_loader, input_dim,
            epochs=args.epochs, batch_size=args.batch_size,
            device=device, use_amp=use_amp
        )
        all_dataset_results[ds_name] = results

        # Per-dataset reports
        print_comparison_table(ds_name, results)
        print_gap_analysis(ds_name, results)
        print_expert_utilization(ds_name, results)
        if device.type == 'cuda':
            print_gpu_efficiency(ds_name, results)

    # Cross-dataset summary
    if len(all_dataset_results) > 1:
        print_final_summary(all_dataset_results)

    print(f"\n{'=' * 90}")
    print("  Benchmark Complete")
    print(f"{'=' * 90}")


if __name__ == '__main__':
    main()
