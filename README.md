# lecheng-service-backend

乐城服务的 Spring Boot 后端基础服务，提供认证、权限、系统管理与监控接口。

## 项目简介

基于 RuoYi-Vue 3.9.1，采用 Maven 多模块结构。当前代码包含登录与验证码、用户、角色、菜单、部门、岗位、字典、参数、通知、操作日志、登录日志、在线用户、缓存和服务器监控等能力，为 `lecheng-service-admin` 提供管理接口。

当前目录经过框架裁剪：`ruoyi-quartz`、`ruoyi-generator` 源码仍保留，但已从父 POM 和启动模块依赖中停用；初始化 SQL 的菜单数据也经过精简。尚无乐城药械、医院、专家、保险、订单及支付的专用业务接口，用户端联调属于后续工作。

## 技术栈

- Java 8（POM 编译目标）、Maven 多模块
- Spring Boot 2.5.15、Spring Security、JWT
- MySQL、Druid 数据源、MyBatis、PageHelper
- Redis、Spring Data Redis / Lettuce
- Swagger 3（Springfox）、Apache POI、Bean Validation
- Quartz / Velocity：保留的可选模块，当前未启用

## 关联仓库

| 项目 | 说明 | GitHub |
| --- | --- | --- |
| lecheng-service-backend | 后端服务与权限基础框架 | [lecheng-service-backend](https://github.com/jiangyi3265/lecheng-service-backend) |
| lecheng-service-admin | Web 管理后台 | [lecheng-service-admin](https://github.com/jiangyi3265/lecheng-service-admin) |
| lecheng-service | UniApp 用户端 / 微信小程序 / H5 | [lecheng-service](https://github.com/jiangyi3265/lecheng-service) |

三个仓库同属乐城服务项目。管理后台采用后端的若依接口约定；用户端当前使用本地示例数据，尚未接入该后端。仓库关联不代表医疗、订单、支付或预约接口已实现。用户端保留原有仓库名称和地址。

## 快速启动

准备 JDK（需支持 Java 8 编译目标）、Maven、MySQL 和 Redis。在仓库根目录执行：

```bash
cp ruoyi-admin/src/main/resources/application.example.yml ruoyi-admin/src/main/resources/application.yml
cp ruoyi-admin/src/main/resources/application-druid.example.yml ruoyi-admin/src/main/resources/application-druid.yml
```

PowerShell 可将 `cp` 换为 `Copy-Item`。已有本地配置时直接复用，不要覆盖。实际配置文件已加入 `.gitignore`；模板通过环境变量读取配置：

| 变量 | 用途 |
| --- | --- |
| `DB_URL` | JDBC 地址，默认指向本机 `lecheng` 数据库 |
| `DB_USERNAME`、`DB_PASSWORD` | 数据库用户及密码，必须自行设置 |
| `TOKEN_SECRET` | 自行生成的高强度随机签名密钥，必须设置；例如使用密码管理器生成至少 64 位随机十六进制文本 |
| `REDIS_HOST`、`REDIS_PASSWORD` | 默认本机 Redis，密码按本地服务配置 |
| `UPLOAD_PATH` | 上传目录，默认 `./uploads` |

在 IDE 的运行环境或当前终端中设置以上变量；Spring Boot 不会自动加载 `.env`。Druid 管理控制台在公开模板中默认关闭。

新环境须创建空的开发数据库，然后在同一个 MySQL 会话中导入 `sql/schema.example.sql`。该文件包含删表语句，只用于全新开发数据库。导入前，将你自选密码经项目的 `SecurityUtils.encryptPassword`（BCrypt）生成的哈希设置到会话变量 `@admin_password_hash`，再运行 `SOURCE sql/schema.example.sql;`。模板保留管理员账号 `admin`，不附带共享默认密码或真实账号资料。新建用户的初始密码参数为空，需要管理员在本地自行配置。

```bash
mvn clean package
java -jar ruoyi-admin/target/ruoyi-admin.jar
```

默认 HTTP 端口为 `8080`，管理后台开发代理转发到此端口。需要先完成数据库、Redis 与密钥配置。`mvn clean package` 会构建父 POM 中启用的模块；不要在父聚合项目直接假设存在可运行的 Spring Boot 主类。

## 项目结构

```text
ruoyi-admin/       启动类、REST 控制器和配置模板
ruoyi-framework/   安全认证、数据源、Web 与服务框架
ruoyi-system/      用户、角色、部门等系统业务及 Mapper
ruoyi-common/      公共实体、工具、注解及异常处理
ruoyi-quartz/      保留的定时任务模块（未启用）
ruoyi-generator/   保留的代码生成模块（未启用）
sql/              无凭据初始化模板；原始 SQL 仅本地保留
bin/              原有开发脚本
```

## 安全与开源说明

实际服务器配置、原始 SQL、数据库文件、日志、构建产物及本地使用手册不上传；源代码中的演示密码已清空。生产配置通过运行环境提供。保留若依原始 `LICENSE` 和源码版权声明。

## 简历描述示例

基于 Spring Boot、Spring Security、MyBatis 与 Redis 整理乐城服务后端基础框架，围绕认证授权、系统管理及监控接口完成多模块工程配置与前后端接口衔接，并将部署凭据从公开源码中隔离。
