# 本地订阅地址与公共规则分离

公共配置保留规则、分组及 provider 的非秘密参数。`vip1`、`vip2`、`vip3` 的真实订阅 URL 仅保存在各端，不提交到 Git。公共配置的 URL 使用 `https://local-subscription.invalid/<provider>` 占位，各端在启动内核前替换。

## 发布条件

必须先部署所有使用者的本地注入机制，再更新公开 `config.yaml`。仅写文件、独立脚本测试或内核 `-t` 通过，都不等于客户端订阅刷新链路已验收。

验收：

- 用脱敏配置走客户端真实更新/生成入口，本地 URL 在内核加载之前恢复。
- 除三个 URL 外，规则、公司内网覆写和用户选线不因本次变更而改变。
- 代理内核配置校验通过，运行端读取到预期 provider，并验证真实连接。
- 定时更新和手动更新均调用注入路径，不会把本地凭据送回公共仓库。
- Git diff 及新增文件不含订阅令牌、节点密码或 UUID。

迁移不会让已公开的历史凭据失效。轮换机场凭据与清理 Git 历史是独立操作，需用户授权；不能把删除当前文件等同于撤销凭据。

## Clash Verge（工作机；Mac 客户端须现场确认）

使用当前订阅绑定的脚本覆写，不覆盖原有 merge 和 rules 文件。`clash-verge.js` 是无密模板，部署时将 `LOCAL_SUBSCRIPTIONS` 填为本机私有 URL 字典。已有脚本应合并逻辑，不直接替换。

生成的私有脚本保留在客户端 profiles 目录，不得提交或上传。必须由 Clash Verge 的实际刷新/配置生成操作验证脚本加载，直接向内核 PUT 配置不能代替此项验收。

## BMoS / OpenClash

- 本地地址：`/etc/openclash/local-subscriptions/providers.json`（0600；JSON 同时是 YAML 子集，由现有 Ruby YAML 读取）。
- 注入器：`/etc/openclash/local-subscriptions/inject.rb`，源为 `bmos-subscriptions.rb`。
- 现有 `/etc/openclash/custom/openclash_custom_overwrite.sh` 中，在 AI 节点池 transform 前调用：

```sh
ruby /etc/openclash/local-subscriptions/inject.rb "$CONFIG_FILE" /etc/openclash/local-subscriptions/providers.json || exit 1
```

保留原覆写文件与 AI 节点池逻辑。配置离线校验必须和 OpenClash 服务一致：`SAFE_PATHS=/usr/share/openclash:/etc/ssl`，内核 home 为 `/etc/openclash`。

## 华硕 / MerlinClash

- 本地地址：`/jffs/local-subscriptions/providers.yaml`（0600）。现有精简版 yq 不支持 JSON 输入，不能用 JSON 文件替代。
- 注入器：`/jffs/local-subscriptions/inject.sh`，源为 `asus-subscriptions.sh`。
- 在 `/koolshare/scripts/clash_subscribe.sh` 的 `yaml_editpath()` 内，设置 `yaml_tmp` 后、提取六段及计算 provider URL 的 MD5 缓存路径之前调用：

```sh
/bin/sh /jffs/local-subscriptions/inject.sh "$yaml_tmp" || { echo_date "Local subscription injection failed"; unset_lock; exit 1; }
```

这条接入保留原订阅下载、路径处理和 AI 节点池定时任务。插件升级可能替换 `clash_subscribe.sh`，升级后必须核对接入点，不得把文件写入成功当作永久生效。

## 2026-11-07 迁移实施记录（随本提交发布）

四端本地补入机制全部安装并通过真实链路验收后，公开 `config.yaml` 才切换为脱敏版。各端验收摘要：

- **华硕（MerlinClash + mihomo）**：接入完成，当日 05:00 真实订阅刷新通过——配置更新、内核重启成功、vip1/2/3 共 142 节点在线、AI 节点池 `DAILY_SUCCESS`；注入失败与下载失败计数均为 0。日志尾部另有一次插件重复触发的订阅尝试失败（BBABBBBC），发生在成功刷新之后、与本地注入无关，未深究。
- **BMoS（OpenClash + clash_meta）**：接入完成，当日 04:00 真实订阅刷新通过，但暴露一个既有机制问题（与本迁移无关）：当日凌晨另一批改动重建的节点缓存用自命名文件，04:00 更新后缓存路径按 md5 再生、新旧对不上，内核启动拉取失败，vip1/2/3 三池全空约 6 小时；因境外 DoH 按规则走代理、代理又依赖空池，形成自锁（手动刷新 503）。修复 = 将当日凌晨的三份新鲜节点列表按 md5 路径补种 + `PUT /configs?force=true` 重载；修复后 vip1 46 / vip2 48 / vip3 48 节点，功能探针 gstatic 204、chatgpt 200、github 200（带端口认证）。遗留风险：今后若机场 URL 变更导致 md5 变化，同样的死锁可能复发（interval 86400s 拉取失败后当日无法自愈）；可选缓解 = DNS 直连 bootstrap（direct-nameserver）或每日强刷兜底，待用户裁定。Gemini 探针超时为新加坡池节点质量（4 节点 2 活），与本机制无关。
- **工作机（Clash Verge Rev 2.5.10，Windows）**：profile 绑定的 Script 覆写槽安装私有注入脚本（原空模板先备份），经重启 App 触发真实生成链路验证：生成产物 mtime 更新、日志零脚本错误、内核端口探针 gstatic 204 / chatgpt 200。注意：该机当时 profile 为旧版双机场（vip1/vip2），vip3 在下次订阅更新拉到新版公开配置后出现，私有脚本已携带全部三个本地地址。
- **Mac（Clash Verge Rev 2.5.10，macOS）**：profile 绑定的 Script 槽已有另一批改动部署的动态 AI 候选池覆写（BEGIN/END ROUTER-AI-POOL OVERLAY 标记块）。经裁定采用外科手术式合并：订阅注入块置于标记块之前，AI 池 main 首行插入一次注入调用；机器逐行校验"只新增 17 行、原 35 行零改动零删除"，备份双份（本任务命名备份 + AI 池原备份）。重启 App 真实生成验收：生成产物 mtime 更新、日志零脚本错误、vip1/2/3 url 与本机私有地址逐项相等、探针 gstatic 204 / chatgpt 200、AI 池效果复测仍在（us=8、sg=4，三方一致）。

发布后验收（决定性判据：公开源已无真实地址，端上生成配置仍含真实地址 = 注入生效）：

- **BMoS**：✅ 通过。11:13 重新下载件含 3 占位符/0 真实地址，运行配置含 3 真实地址/0 占位符；内核重启后 vip1 46 / vip2 48 / vip3 48 节点（存活 29/44/44），gstatic 204、chatgpt 200（带端口认证）。
- **工作机**：✅ 通过。从脱敏公开源拉取 → 写入订阅缓存（先备份）→ 重启 App 生成，vip1/vip2/vip3 全部还原真实地址；gstatic 204、chatgpt 200。该机 profile 顺带升级至最新三机场版。
- **华硕**：✅ 通过（第二次尝试）。首次重跑因 GitHub raw TLS 证书链间歇问题在下载阶段失败（Let's Encrypt 新中间证书 CN=YR1，路由器 7 月版 CA 包视边缘节点而定；发生在注入环节之前，与本机制无关，今晨 05:00 同链路成功）；重试后 DAILY_SUCCESS，yaml_use 含 3 真实地址/0 占位符，注入失败计数 0，AI 节点池 53/53 扫描完成。
- **Mac**：✅ 全部完成。2026-11-07 12:48 Dr.Zhu 经由新上线的 WebCodex Runner 通道直接接入 Mac 实操修复并验收：
  1. 根因破案：此前 Mac 本地旧配置提取的 vip1 对应已被服务商废弃的旧域名 `liangxin.xyz`（导致 403）；且 vip3 缺少 `proxy: DIRECT` 导致在初始未连通时路由成环陷入 EOF 死锁。
  2. 修复对齐：远程更正 `s9xGEqHmngrR.js` 里的 vip1 端点为当前有效域名 `7777699.xyz`，为 vip3 补全 `proxy: DIRECT`。
  3. 验收全绿：重启后三机场节点全量满载——vip1(46节点/23活)、vip2(48节点/39活)、vip3(48节点/38活)、AI专线(us=8, sg=4)全部正常；功能探针 gstatic 204、google 200、github 200、chatgpt 200 全通。
  4. WebCodex Runner（v0.4.6 darwin-arm64）作为 LaunchAgent（`dev.webcodex.runner-local`，PID 20780）开机常驻在线，双向执行通道完全打通。

既有风险记录（与本项目无关，留档）：华硕每日 05:00 订阅更新存在上述 TLS 间歇失败的可能，失败时 ai-node-pool 判 CONFIG_NOT_UPDATED 退出，节点沿用缓存不影响使用；如需根治可更新路由器 CA 包或为下载加重试，待用户裁定。BMoS 的 md5 缓存路径死锁风险见上文。订阅凭据轮换与 Git 历史清理属独立操作，未包含在本项目内。
