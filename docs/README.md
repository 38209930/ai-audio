# AI Audio 文档中心

本目录收录 AI Audio 的使用、开发、部署和产品规划文档。建议按角色阅读对应文档。

## 用户文档

- [使用说明书](USAGE.zh-CN.md)：面向最终用户，说明视频格式、时长建议、模型准备、本地 Web UI、CLI 使用、输出文件和常见问题。

## 开发文档

- [开发文档](DEVELOPMENT.md)：面向开发者，说明项目结构、本地开发环境、转写流水线、云端 API、Windows 客户端、数据库迁移和验证方式。
- [API 契约](product/API_CONTRACT.md)：说明云端接口、请求响应格式、错误码和游客试用、验证码、短信登录等接口。
- [产品架构](product/ARCHITECTURE.md)：说明 Windows 客户端、本地引擎、云端 API、MySQL、Redis、模型管理之间的边界。
- [分阶段实施计划](product/IMPLEMENTATION_PLAN.md)：说明从技术底座到 Windows 正式版、字幕翻译和 macOS DMG 的版本迭代路线。

## 部署文档

- [部署文档](DEPLOYMENT.zh-CN.md)：面向运维和部署人员，说明阿里云 ECS、MySQL、Redis、OpenResty API、HTTPS、迁移、重启和验收流程。
- [阿里云部署脚本说明](../deploy/aliyun/README.md)：说明 `deploy/aliyun` 目录中的 `.env` 模板、Docker Compose、Nginx 模板、迁移脚本、重启脚本和 smoke test。

## 推荐阅读顺序

最终用户：

1. [使用说明书](USAGE.zh-CN.md)

开发者：

1. [开发文档](DEVELOPMENT.md)
2. [API 契约](product/API_CONTRACT.md)
3. [产品架构](product/ARCHITECTURE.md)

部署人员：

1. [部署文档](DEPLOYMENT.zh-CN.md)
2. [阿里云部署脚本说明](../deploy/aliyun/README.md)

