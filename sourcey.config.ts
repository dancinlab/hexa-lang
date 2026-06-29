import { defineConfig, markdown } from "sourcey";

export default defineConfig({
  name: "Hexa Lang API",
  navigation: { tabs: [{ tab: "API", source: markdown({ groups: [{ group: "Modules", pages: [
    "pages/.verdicts_hexa-fusion_extract_runtime_cuda",
    "pages/.verdicts_hexa-fusion_ff-dutycycle-build_bucket_nsys",
    "pages/.verdicts_hexa-fusion_ff-dutycycle-build_insert_fusion_protos",
    "pages/.verdicts_hexa-fusion_m5-build_m5_callN_post2",
    "pages/.verdicts_hexa-fusion_p1b-aprime2-build_insert_fusion_protos",
    "pages/.verdicts_hexa-fusion_p1b-aprime3-build_insert_fusion_protos",
    "pages/.verdicts_hexa-fusion_precision-change-build_insert_fusion_protos",
    "pages/.verdicts_hexa-fusion_precision-change-build_patch_precision",
    "pages/.verdicts_verify-kit-iit-calibrate_mi_phi_independent",
    "pages/.verdicts_verify-kit-iit-calibrate_pyphi_reference",
    "pages/ATLAS_hypotheses_exp_hcx422",
    "pages/ATLAS_hypotheses_exp_hcx423",
    "pages/ATLAS_hypotheses_exp_hcx424",
    "pages/ATLAS_hypotheses_translate_helper",
    "pages/ATLAS_hypotheses_verify_443",
    "pages/ATLAS_hypotheses_verify_444",
    "pages/ATLAS_hypotheses_verify_445",
    "pages/ATLAS_hypotheses_verify_h_rob_3",
    "pages/ATLAS_hypotheses_verify_h_rob_4",
    "pages/ATLAS_hypotheses_verify_hcx428",
] }] }) }] }, theme: { preset: "default" }, repo: "https://github.com/dancinlab/hexa-lang" });
