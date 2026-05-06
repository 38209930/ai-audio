import React from "react";
import ReactDOM from "react-dom/client";
import { API_BASE_URL, API_ENDPOINTS } from "./apiConfig";
import "./styles.css";

type Page = "home" | "login" | "tasks" | "models" | "help" | "updates" | "donate";

type GuestSession = {
  accessToken: string;
  expiresIn: number;
  guest: {
    id: string;
    trialStartedAt: string;
    trialExpiresAt: string;
    remainingDays: number;
  };
};

type ApiResponse<T> = {
  ok: boolean;
  data: T | null;
  error: { code: string; message: string } | null;
  requestId: string;
};

const pages: Array<{ id: Page; label: string }> = [
  { id: "home", label: "首页" },
  { id: "login", label: "登录" },
  { id: "tasks", label: "转写任务" },
  { id: "models", label: "模型管理" },
  { id: "help", label: "使用帮助" },
  { id: "updates", label: "版本更新" },
  { id: "donate", label: "捐助" },
];

const donateAssets = import.meta.glob("./assets/donate/*", {
  eager: true,
  query: "?url",
  import: "default",
}) as Record<string, string>;

function getDonateAsset(name: string) {
  return donateAssets[`./assets/donate/${name}`];
}

function getDeviceId() {
  const key = "ai-audio-device-id";
  const existing = localStorage.getItem(key);
  if (existing) {
    return existing;
  }
  const generated =
    globalThis.crypto?.randomUUID?.() ??
    `device_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  localStorage.setItem(key, generated);
  return generated;
}

async function postJson<T>(path: string, body: unknown) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const payload = (await response.json()) as ApiResponse<T>;
  if (!response.ok || !payload.ok || !payload.data) {
    throw new Error(payload.error?.message ?? "请求失败");
  }
  return payload.data;
}

function App() {
  const [page, setPage] = React.useState<Page>("home");
  const [session, setSession] = React.useState<GuestSession | null>(() => {
    const raw = localStorage.getItem("ai-audio-guest-session");
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as GuestSession;
    } catch {
      localStorage.removeItem("ai-audio-guest-session");
      localStorage.removeItem("ai-audio-access-token");
      return null;
    }
  });

  const trialExpired = !!session && session.guest.remainingDays <= 0;

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
        {page === "home" && <Home session={session} />}
        {page === "login" && <Login session={session} onSession={setSession} />}
        {page === "tasks" && <Tasks session={session} trialExpired={trialExpired} />}
        {page === "models" && <Models />}
        {page === "help" && <Help />}
        {page === "updates" && <Updates />}
        {page === "donate" && <Donate />}
      </section>
    </main>
  );
}

function Home({ session }: { session: GuestSession | null }) {
  return (
    <section>
      <h1>视频转字幕与教程整理</h1>
      <p>本地转写视频课程，输出 SRT 字幕、Markdown 时间轴文稿、详细教程和实施方案。</p>
      {session ? (
        <p className="status success">游客试用剩余 {session.guest.remainingDays} 天</p>
      ) : (
        <p className="status">未登录，可使用 30 天游客试用。</p>
      )}
      <div className="grid">
        <InfoCard title="账号" text="当前支持游客试用；手机号验证码登录将在短信服务配置完成后开放。" />
        <InfoCard title="模型" text="必须配置 ASR 模型后才能转写，支持 CPU 和 NVIDIA GPU。" />
        <InfoCard title="输出" text="SRT、Markdown 时间轴文稿、详细教程，可选 solution.md。" />
      </div>
    </section>
  );
}

function Login({
  session,
  onSession,
}: {
  session: GuestSession | null;
  onSession: (session: GuestSession) => void;
}) {
  const [loading, setLoading] = React.useState(false);
  const [message, setMessage] = React.useState("");

  async function loginAsGuest() {
    setLoading(true);
    setMessage("");
    try {
      const data = await postJson<GuestSession>(API_ENDPOINTS.guestLogin, {
        deviceId: getDeviceId(),
        osName: "Windows",
        osVersion: navigator.userAgent,
        appVersion: "0.1.0",
      });
      localStorage.setItem("ai-audio-guest-session", JSON.stringify(data));
      localStorage.setItem("ai-audio-access-token", data.accessToken);
      onSession(data);
      setMessage(`游客试用已开启，剩余 ${data.guest.remainingDays} 天。`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "游客登录失败");
    } finally {
      setLoading(false);
    }
  }

  return (
    <section>
      <h1>登录</h1>
      <div className="settings-panel">
        <h2>游客试用</h2>
        <p>无需手机号，按当前设备发放 30 天试用期。</p>
        <button className="primary" onClick={loginAsGuest} disabled={loading}>
          {loading ? "正在登录..." : "游客试用 30 天"}
        </button>
        {session && <p className="status success">当前游客身份：{session.guest.id}</p>}
        {message && <p className="status">{message}</p>}
      </div>
      <div className="settings-panel disabled-panel">
        <h2>手机号验证码登录</h2>
        <p>短信服务配置中，暂未开放。</p>
        <label>手机号</label>
        <input placeholder="短信服务配置完成后可用" disabled />
        <button disabled>获取验证码</button>
      </div>
    </section>
  );
}

function Tasks({
  session,
  trialExpired,
}: {
  session: GuestSession | null;
  trialExpired: boolean;
}) {
  const disabled = !session || trialExpired;
  return (
    <section>
      <h1>转写任务</h1>
      <p>只显示原文件名、大小、格式和时长；不显示视频或图片预览。</p>
      {disabled && (
        <p className="status warning">
          {!session ? "请先游客登录或手机号登录后再开始任务。" : "游客试用已到期，无法创建新任务。"}
        </p>
      )}
      <div className="drop-zone">选择视频文件</div>
      <div className="form-row">
        <label>语言</label>
        <input defaultValue="zh" disabled={disabled} />
      </div>
      <div className="form-row">
        <label>切片秒数</label>
        <input defaultValue="600" disabled={disabled} />
      </div>
      <button className="primary" disabled={disabled}>
        开始转写
      </button>
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
      <p>支持视频格式、时长建议、CPU/GPU/Apple 芯片支持、模型下载和耗时预测。</p>
    </section>
  );
}

function Updates() {
  return (
    <section>
      <h1>版本更新</h1>
      <p>云端版本检查 API 支持普通更新和强制更新。</p>
    </section>
  );
}

function Donate() {
  return (
    <section>
      <h1>捐助</h1>
      <p>如果这个工具对你有帮助，可以通过微信捐助或关注公众号获取更新。</p>
      <div className="donate-grid">
        <QrCard title="微信收款码" src={getDonateAsset("wechat-pay.png")} />
        <QrCard title="公众号二维码" src={getDonateAsset("wechat-official-account.png")} />
      </div>
    </section>
  );
}

function QrCard({ title, src }: { title: string; src?: string }) {
  const [failed, setFailed] = React.useState(false);
  return (
    <article className="card qr-card">
      <h2>{title}</h2>
      {src && !failed ? (
        <img src={src} alt={title} onError={() => setFailed(true)} />
      ) : (
        <div className="qr-placeholder">二维码待配置</div>
      )}
    </article>
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
