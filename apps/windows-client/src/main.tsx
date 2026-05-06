import React from "react";
import ReactDOM from "react-dom/client";
import "./styles.css";

type Page = "home" | "login" | "tasks" | "models" | "help" | "updates";

const pages: Array<{ id: Page; label: string }> = [
  { id: "home", label: "首页" },
  { id: "login", label: "登录" },
  { id: "tasks", label: "转写任务" },
  { id: "models", label: "模型管理" },
  { id: "help", label: "使用帮助" },
  { id: "updates", label: "版本更新" },
];

function App() {
  const [page, setPage] = React.useState<Page>("home");

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">AI Audio</div>
        {pages.map((item) => (
          <button
            key={item.id}
            className={item.id === page ? "nav-item active" : "nav-item"}
            onClick={() => setPage(item.id)}
          >
            {item.label}
          </button>
        ))}
      </aside>
      <section className="content">
        {page === "home" && <Home />}
        {page === "login" && <Login />}
        {page === "tasks" && <Tasks />}
        {page === "models" && <Models />}
        {page === "help" && <Help />}
        {page === "updates" && <Updates />}
      </section>
    </main>
  );
}

function Home() {
  return (
    <section>
      <h1>视频转字幕与教程整理</h1>
      <p>Windows 商业版客户端骨架。当前页面用于 v0.1 产品骨架验收。</p>
      <div className="grid">
        <InfoCard title="账号" text="手机号验证码登录，云端 OpenResty/Lua API。" />
        <InfoCard title="模型" text="必须配置 ASR 模型后才能转写。" />
        <InfoCard title="输出" text="SRT、Markdown 时间轴文稿、详细教程，可选 solution.md。" />
      </div>
    </section>
  );
}

function Login() {
  return (
    <section>
      <h1>手机号登录</h1>
      <p>v0.2 接入真实 API：图形点选验证码、短信验证码、token 本地安全存储。</p>
      <label>手机号</label>
      <input placeholder="请输入手机号" />
      <button className="primary">获取图形验证码</button>
    </section>
  );
}

function Tasks() {
  return (
    <section>
      <h1>转写任务</h1>
      <p>只显示原文件名、大小、格式和时长；不显示视频或图片预览。</p>
      <div className="drop-zone">选择视频文件</div>
      <div className="form-row">
        <label>语言</label>
        <input defaultValue="zh" />
      </div>
      <div className="form-row">
        <label>切片秒数</label>
        <input defaultValue="600" />
      </div>
      <button className="primary">开始转写</button>
    </section>
  );
}

function Models() {
  return (
    <section>
      <h1>模型管理</h1>
      <p>ASR 模型是必填配置。免费模型提供直达下载链接；API 模型提供配置表单。</p>
      <div className="settings-panel">
        <h2>ASR 模型</h2>
        <p>faster-whisper large-v3 / medium / small</p>
        <button>检查本地模型</button>
        <button>全选下载</button>
      </div>
      <div className="settings-panel">
        <h2>解决方案模型</h2>
        <input placeholder="Provider" />
        <input placeholder="Base URL" />
        <input placeholder="API Key" type="password" />
        <input placeholder="Model" />
      </div>
    </section>
  );
}

function Help() {
  return (
    <section>
      <h1>使用帮助</h1>
      <p>列出支持格式、时长建议、CPU/GPU/Apple 芯片支持、模型下载和耗时预测。</p>
    </section>
  );
}

function Updates() {
  return (
    <section>
      <h1>版本更新</h1>
      <p>v0.8 接入云端版本检查 API，支持普通更新和强制更新。</p>
    </section>
  );
}

function InfoCard({ title, text }: { title: string; text: string }) {
  return (
    <article className="card">
      <h2>{title}</h2>
      <p>{text}</p>
    </article>
  );
}

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(<App />);

