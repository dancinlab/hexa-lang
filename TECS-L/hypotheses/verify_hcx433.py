#!/usr/bin/env python3
"""H-CX-433: Prisoner's Dilemma Cooperation Condition = sigma_{-1}(6)=2"""
import numpy as np
import warnings
warnings.filterwarnings('ignore')

np.random.seed(42)

# PD payoffs: CC=(3,3), CD=(0,5), DC=(5,0), DD=(1,1)
R, T, S, P = 3, 5, 0, 1  # Reward, Temptation, Sucker, Punishment

def softmax_scalar(x):
    e = np.exp(x - np.max(x))
    return e / e.sum()

class PDAgent:
    """Simple policy gradient agent for PD"""
    def __init__(self):
        self.theta = np.random.randn(2) * 0.1  # [cooperate_logit, defect_logit]
        self.history = []

    def act(self):
        probs = softmax_scalar(self.theta)
        action = np.random.choice([0, 1], p=probs)  # 0=cooperate, 1=defect
        return action, probs

    def update(self, action, reward, lr=0.05):
        probs = softmax_scalar(self.theta)
        # Policy gradient: increase probability of action proportional to reward
        grad = np.zeros(2)
        grad[action] = reward * (1 - probs[action])
        grad[1-action] = -reward * probs[1-action]
        self.theta += lr * grad

def compute_payoff_n_player(actions, player_idx):
    """N-player PD: payoff depends on number of cooperators"""
    N = len(actions)
    n_coop = sum(1 for a in actions if a == 0)
    my_action = actions[player_idx]

    if my_action == 0:  # cooperate
        # Reward scales with cooperators
        payoff = R * (n_coop / N) + S * (1 - n_coop / N)
    else:  # defect
        payoff = T * (n_coop / N) + P * (1 - n_coop / N)
    return payoff

print("=" * 60)
print("H-CX-433: Prisoner's Dilemma Cooperation = sigma_{-1}(6)=2")
print("=" * 60)

# Experiment 1: Iterated PD with N agents, policy gradient
print("\n--- Experiment 1: N-player Iterated PD ---")
print(f"Payoff: CC=({R},{R}), CD=({S},{T}), DC=({T},{S}), DD=({P},{P})")
print(f"Training: 2000 rounds, policy gradient\n")

results = {}
for N in range(2, 11):
    np.random.seed(42)
    agents = [PDAgent() for _ in range(N)]
    coop_history = []

    for round_num in range(2000):
        actions = []
        probs_list = []
        for agent in agents:
            action, probs = agent.act()
            actions.append(action)
            probs_list.append(probs)

        # Compute payoffs and update
        for i, agent in enumerate(agents):
            payoff = compute_payoff_n_player(actions, i)
            agent.update(actions[i], payoff, lr=0.02)

        # Record cooperation rate
        coop_rate = sum(1 for a in actions if a == 0) / N
        coop_history.append(coop_rate)

    # Last 200 rounds average
    final_coop = np.mean(coop_history[-200:])
    final_std = np.std(coop_history[-200:])
    results[N] = {
        'coop_rate': final_coop,
        'coop_std': final_std,
        'history': coop_history
    }

print(f"{'N':>3} | {'Coop Rate':>9} | {'Std':>6} | {'Bar':>30}")
print("-" * 55)
for N in range(2, 11):
    r = results[N]
    bar_len = int(r['coop_rate'] * 30)
    bar = "#" * bar_len + "." * (30 - bar_len)
    print(f"{N:>3} | {r['coop_rate']:>9.4f} | {r['coop_std']:>6.3f} | {bar}")

# ASCII graph: N vs cooperation rate
print("\n--- ASCII Graph: N vs Cooperation Rate ---")
print("Coop")
print("Rate")
for level in [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]:
    line = f"{level:.1f} |"
    for N in range(2, 11):
        r = results[N]
        if r['coop_rate'] >= level - 0.05:
            if N == 2:
                line += " * "  # sigma_{-1}(6)=2
            else:
                line += " o "
        else:
            line += "   "
    print(line)
print("    +" + "---" * 9)
print("      " + "  ".join([str(N) for N in range(2, 11)]))
print("                    N (players)")
print("    * = N=2=sigma_{-1}(6)")

# Experiment 2: Axelrod tournament strategies
print("\n--- Experiment 2: Axelrod Tournament ---")
print("Strategies: TFT, AllC, AllD, Pavlov, Random")
print("Memory length test: does sigma_{-1}(6)=2 appear?\n")

def tit_for_tat(history, opp_history):
    if len(opp_history) == 0:
        return 0  # cooperate
    return opp_history[-1]  # copy opponent

def always_cooperate(history, opp_history):
    return 0

def always_defect(history, opp_history):
    return 1

def pavlov(history, opp_history):
    if len(history) == 0:
        return 0
    if history[-1] == opp_history[-1]:
        return 0  # cooperate if same
    return 1  # defect if different

def random_strategy(history, opp_history):
    return np.random.choice([0, 1])

def tft_memory_k(k):
    """TFT with memory k: cooperate if opponent cooperated in last k rounds majority"""
    def strategy(history, opp_history):
        if len(opp_history) < k:
            return 0
        recent = opp_history[-k:]
        return 1 if sum(recent) > k / 2 else 0
    return strategy

strategies = {
    'TFT': tit_for_tat,
    'AllC': always_cooperate,
    'AllD': always_defect,
    'Pavlov': pavlov,
    'Random': random_strategy,
}

def play_match(strat1, strat2, rounds=200):
    h1, h2 = [], []
    scores = [0, 0]
    for _ in range(rounds):
        a1 = strat1(h1, h2)
        a2 = strat2(h2, h1)
        if a1 == 0 and a2 == 0:
            scores[0] += R; scores[1] += R
        elif a1 == 0 and a2 == 1:
            scores[0] += S; scores[1] += T
        elif a1 == 1 and a2 == 0:
            scores[0] += T; scores[1] += S
        else:
            scores[0] += P; scores[1] += P
        h1.append(a1)
        h2.append(a2)
    return scores

# Tournament
strat_names = list(strategies.keys())
n_strats = len(strat_names)
tournament = np.zeros((n_strats, n_strats))

for i, s1 in enumerate(strat_names):
    for j, s2 in enumerate(strat_names):
        np.random.seed(42)
        scores = play_match(strategies[s1], strategies[s2], rounds=200)
        tournament[i, j] = scores[0]

print("Tournament Scores (row vs col, 200 rounds):")
print(f"{'':>8}", end="")
for s in strat_names:
    print(f" {s:>7}", end="")
print("  Total")
print("-" * 55)
for i, s in enumerate(strat_names):
    total = tournament[i].sum()
    print(f"{s:>8}", end="")
    for j in range(n_strats):
        print(f" {tournament[i,j]:>7.0f}", end="")
    print(f"  {total:>6.0f}")

# Memory length analysis
print("\n--- Memory Length vs Performance ---")
print("TFT with memory k=1..6: which k is optimal?")
print(f"{'Memory k':>8} | {'vs AllC':>7} | {'vs AllD':>7} | {'vs TFT':>7} | {'vs Pavlov':>9} | {'Total':>7}")
print("-" * 55)

memory_scores = {}
for k in range(1, 7):
    strat = tft_memory_k(k)
    total = 0
    scores_by_opp = {}
    for opp_name, opp_strat in strategies.items():
        np.random.seed(42)
        sc = play_match(strat, opp_strat, rounds=200)
        scores_by_opp[opp_name] = sc[0]
        total += sc[0]
    memory_scores[k] = total
    print(f"{k:>8} | {scores_by_opp.get('AllC',0):>7.0f} | {scores_by_opp.get('AllD',0):>7.0f} | "
          f"{scores_by_opp.get('TFT',0):>7.0f} | {scores_by_opp.get('Pavlov',0):>9.0f} | {total:>7.0f}")

best_k = max(memory_scores, key=memory_scores.get)
print(f"\nOptimal memory length: k={best_k}")
print(f"sigma_{{-1}}(6) = 2")
print(f"Match: {'Yes!' if best_k == 2 else 'No, k=' + str(best_k)}")

# Experiment 3: 1/N cooperation decay model
print("\n--- Experiment 3: Cooperation Decay Model ---")
print("Testing: does coop_rate ~ sigma_{-1}(6)/N = 2/N ?")
print(f"{'N':>3} | {'Measured':>8} | {'2/N':>6} | {'1/N':>6} | {'Best Fit':>8}")
print("-" * 45)

coop_rates = [results[N]['coop_rate'] for N in range(2, 11)]
Ns = list(range(2, 11))

# Fit: coop = a/N + b
from numpy.polynomial import polynomial as P_fit
# Simple: measure correlation with 2/N and 1/N
two_over_n = [2.0/N for N in Ns]
one_over_n = [1.0/N for N in Ns]

corr_2n = np.corrcoef(coop_rates, two_over_n)[0, 1]
corr_1n = np.corrcoef(coop_rates, one_over_n)[0, 1]

for i, N in enumerate(Ns):
    print(f"{N:>3} | {coop_rates[i]:>8.4f} | {2.0/N:>6.3f} | {1.0/N:>6.3f} | {'2/N' if abs(coop_rates[i] - 2.0/N) < abs(coop_rates[i] - 1.0/N) else '1/N':>8}")

print(f"\nCorrelation with 2/N (sigma_{{-1}}(6)/N): r = {corr_2n:.4f}")
print(f"Correlation with 1/N:                    r = {corr_1n:.4f}")
print(f"Better model: {'2/N (sigma_{-1}(6))' if abs(corr_2n) > abs(corr_1n) else '1/N'}")

# ASCII: cooperation rate vs N with 2/N overlay
print("\n--- ASCII Graph: Cooperation Rate vs N with 2/N overlay ---")
print("Rate")
for level in np.arange(1.0, -0.05, -0.1):
    line = f"{level:.1f} |"
    for i, N in enumerate(Ns):
        measured = coop_rates[i]
        theory = 2.0 / N
        if abs(measured - level) < 0.05 and abs(theory - level) < 0.05:
            line += " @ "  # both
        elif abs(measured - level) < 0.05:
            line += " * "  # measured
        elif abs(theory - level) < 0.05:
            line += " o "  # theory 2/N
        else:
            line += "   "
    print(line)
print("    +" + "---" * len(Ns))
print("      " + "  ".join([str(N) for N in Ns]))
print("    * = measured, o = 2/N theory, @ = both match")

print("\n--- Summary ---")
print(f"  sigma_{{-1}}(6) = 2 (sum of reciprocals of proper divisors of 6)")
print(f"  N=2 cooperation rate: {results[2]['coop_rate']:.4f}")
print(f"  N=10 cooperation rate: {results[10]['coop_rate']:.4f}")
print(f"  Decay ratio (N=2/N=10): {results[2]['coop_rate']/max(results[10]['coop_rate'],0.001):.2f}x")
print(f"  Optimal memory length: k={best_k} (prediction: 2)")
print(f"  Corr(coop, 2/N): {corr_2n:.4f}")
print(f"  Corr(coop, 1/N): {corr_1n:.4f}")
