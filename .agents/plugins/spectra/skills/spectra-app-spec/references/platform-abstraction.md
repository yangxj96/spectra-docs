# uni-app 平台抽象参考

当同一能力在 H5、App 或微信小程序需要不同实现时，放在 `src/platform/{feature}/`，由统一入口导出平台实现。业务代码只依赖统一接口。

推荐结构：

```text
src/platform/{feature}/
├── types.ts
├── index.ts
├── web.ts
├── android.ts
└── wechat.ts
```

- 权限、设备、推送、原生 API 等能力必须隔离在平台抽象中。
- 业务组件不得直接调用 `plus`、平台原生对象或重复写平台分支。
- 仅有模板结构差异时，可以在模板中使用 uni-app 条件编译。
- 新增抽象应先定义跨平台接口，再补齐目标平台实现和最小验证。
