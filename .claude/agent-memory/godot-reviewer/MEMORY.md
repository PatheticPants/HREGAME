# Memory Index

- [Cross-platform safeguards already in place](project_cross_platform_safeguards.md) — verify_content.py, .gitattributes/.gitignore, why cp1252 incident matters here.
- [Test entry points](project_test_entry_points.md) — where test_rules/test_presentation/test_session/qa_capture live and how to run them.
- [Concurrent agent sessions on the same repo](project_concurrent_agents.md) — HEAD and the working tree can change mid-review; avoid git stash, prefer worktrees, don't chase a moving target.
- [ErasureCheck/Rasura status as of af5dd24](project_erasure_check_status.md) — RESOLVED as of 01588ea (case_08 + test_rules coverage); don't re-flag without checking.
- [z_index latent cases: the candle](project_zindex_latent_cases.md) — candle.gd:142 permanent z_index=1, same shape as the fixed wax_pool bug, unguarded by test/capture.
- [Measured-probe coverage caveat](feedback_measured_probe_coverage.md) — the 5.9ms probe never impresses a wax seal; don't let it suppress findings in paths it doesn't run (e.g. wax_pool struck-polygon recompute).
