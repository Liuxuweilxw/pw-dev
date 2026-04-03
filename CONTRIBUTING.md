# Contributing

感谢你参与 `pw-dev` 项目。

## 分支规范

- 基于 `main` 创建功能分支：`feature/<name>`、`fix/<name>`。
- 不直接在 `main` 上进行日常开发。

## 提交规范

- 建议采用 `type: summary` 形式：
  - `feat:` 新功能
  - `fix:` 修复问题
  - `refactor:` 重构
  - `docs:` 文档更新
  - `chore:` 工程维护
- 每次提交聚焦单一主题，避免混入无关改动。

## 代码与目录约定

- Flutter 前端代码在 `lib/`。
- Dart 后端代码在 `backend/`。
- 业务改动优先补充对应文档（`README.md` 或专题说明文档）。

## 本地检查

提交前建议至少执行：

```bash
flutter analyze
flutter test
```

后端改动建议额外执行：

```bash
cd backend
dart analyze
dart run bin/server.dart
```

## PR 流程

1. 同步最新 `main`。
2. 推送分支并发起 Pull Request。
3. 按模板填写变更说明、测试结果、风险评估。
4. 通过评审后合并。

## 忽略与构建产物

- 不提交编译缓存和产物（如 `build/`、`.dart_tool/`、`backend/bin/*.exe`）。
- 仓库已有 `.gitignore`，如新增工具链请及时补充忽略项。

## Issue 建议

提问题时建议包含：

- 环境信息（系统、Flutter/Dart版本）
- 复现步骤
- 预期结果与实际结果
- 错误日志或截图
