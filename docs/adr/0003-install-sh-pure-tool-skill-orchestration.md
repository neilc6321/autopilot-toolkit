# install.sh 退化为纯工具，skill 承担编排

此前 `install.sh` 是单体脚本：自己发现 expected set，自己判断每个 symlink 状态，自己执行创建/替换/跳过，自己输出 summary。首次安装和更新走同一条路径，差异只在用户是否手动 `git pull`。

我们决定把 install.sh 拆成两层：

- `install.sh` 退化为**无状态的纯执行工具**，暴露三个原子子命令：`sync`、`unlink`、`link-principles`。不再自己做发现和诊断。
- `toolkit-setup` (原 `toolkit-selfcheck`) 成为**编排层**：负责发现 expected set、诊断每个 skill 的状态、计算增量操作、调用 install.sh 执行、最后验证干净。

这样安装和更新在用户侧统一为运行 `/toolkit-setup` 一个入口，内部由 skill 编排完成全部同步和清理。

## Considered Options

**A) 保持 install.sh 单体，在 README 里写两段不同的命令序列**
- 简单，不破坏现有代码
- 但无法处理移除（残留清理），也缺少结构化输出供上层消费

**B) install.sh 增加子命令 + skill 编排（采用）**
- 纯工具可单独测试，接口稳定
- skill 提供引导、诊断、覆盖所有场景（含移除和 principles）
- 代价：skill 在编排时为每个 skill 调用一次 bash（19+ 次），终端输出较吵。接受。

## Consequences

- `install.sh` CLI 契约改变：不再支持无参运行。旧 README 里的 `bash install.sh` 不再有效。
- `toolkit-selfcheck` 重命名为 `toolkit-setup`，职责从只读验证扩展到编排执行。
- 首次安装和更新在 README 里仍需分别说明（步骤差异在 `git clone` vs `git pull`），但执行入口统一为 `/toolkit-setup`。
