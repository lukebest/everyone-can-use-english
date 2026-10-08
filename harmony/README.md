# Enjoy for HarmonyOS

Stage 模型工程（API 24 / HarmonyOS 6.1.1）。用 DevEco Studio 打开 `harmony/` 目录，签名后安装到手机。

课程、跟读、对话、生词都在这个应用里。查词、翻译、分析、润色、对话由手机直接请求 GLM Coding Plan 或 MiniMax，在「我的」里填写两家的接口地址、API Key 和模型，并选择当前使用哪一家。Key 只保存在手机上。

默认地址：

- GLM：`https://open.bigmodel.cn/api/coding/paas/v4`，模型 `glm-5.3`。海外账号可改成 `https://api.z.ai/api/coding/paas/v4`。
- MiniMax：`https://api.minimaxi.com/v1`，模型 `MiniMax-M2.7`。

Z.ai 文档把 Coding Plan 额度描述为供受支持的编程工具使用。这个应用不是那些工具，套餐接口有可能拒绝请求，或按对方规则计费。如果套餐地址不通，把 GLM 地址改成按量接口 `https://open.bigmodel.cn/api/paas/v4`（海外为 `https://api.z.ai/api/paas/v4`）。

## 课程资源

发音课来自 `1000-hours/sounds-of-american-english`。生成内置页面和音频：

```bash
cd harmony
npm install
npm run build:course
```

输出在 `entry/src/main/resources/rawfile/course/`（已加入 `.gitignore`）。课文在 ArkWeb 里打开，点读按钮播放 rawfile 音频，划词后点「查词」。

## 语音中转

英文朗读用系统 Core Speech Kit 的 en-US 离线音色（劳拉，`person: 8`），需要在系统里下载英语语音。系统语音识别目前不支持英文，所以「自动分句」和「评分」可选地走 [`relay/`](../relay/) 上的 whisper.cpp。不填语音中转地址时，查词和对话仍然可用。

先按 `relay/README.md` 启动服务。在应用的「我的」里填写 `http://<电脑局域网 IP>:8787` 和 `RELAY_TOKEN`。明文 HTTP 已在 `network_config.json` 里打开，只适合你自己的中转。

## 许可

仓库是 GPL-3.0-only，这个应用也是。`new-edition-drafts/` 里作者保留版权的媒体没有打进应用。
