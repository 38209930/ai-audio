import React from "react";
import ReactDOM from "react-dom/client";
import { invoke } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import "./styles.css";

type Page = "home" | "tasks" | "models" | "help" | "updates" | "donate";

type GpuStatus = {
  available: boolean;
  message?: string;
  gpus: string[];
};

type ModelItem = {
  id: string;
  repo: string;
  name: string;
  purpose: string;
  hardware: string;
  size: string;
  targetDir: string;
  ready: boolean;
  missingFiles: string[];
  mirrorUrl: string;
  originalUrl: string;
};

type ModelStatus = {
  modelRoot: string;
  requiredFiles: string[];
  models: ModelItem[];
};

type VideoInfo = {
  path: string;
  fileName: string;
  format: string;
  sizeBytes: number;
  durationSeconds: number;
  durationText: string;
};

type TranscribeResult = {
  result: {
    outputDir: string;
    srt: string;
    transcriptMd: string;
    tutorialMd: string;
    implementationPlanMd: string;
    subtitleCount: number;
    durationSeconds: number;
    audioSegments: string[];
  };
  log: Array<Record<string, unknown>>;
  stderr: string;
};

type Settings = {
  modelDir: string;
  modelId: string;
  language: string;
  segmentSeconds: number;
  device: string;
  computeType: string;
};

const pages: Array<{ id: Page; label: string }> = [
  { id: "home", label: "首页" },
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

function formatBytes(value: number) {
  if (value > 1024 * 1024 * 1024) {
    return `${(value / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  return `${(value / 1024 / 1024).toFixed(2)} MB`;
}

function eventLabel(event: string) {
  const labels: Record<string, string> = {
    prepare: "准备任务",
    extract_audio: "提取音频",
    split_audio: "切分音频",
    load_model: "加载模型",
    transcribe_segment: "转写片段",
    write_files: "写出文件",
    complete: "处理完成",
  };
  return labels[event] ?? event;
}

function App() {
  const [page, setPage] = React.useState<Page>("home");
  const [engineVersion, setEngineVersion] = React.useState("");
  const [gpu, setGpu] = React.useState<GpuStatus | null>(null);
  const [modelStatus, setModelStatus] = React.useState<ModelStatus | null>(null);
  const [video, setVideo] = React.useState<VideoInfo | null>(null);
  const [message, setMessage] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [downloadBusy, setDownloadBusy] = React.useState("");
  const [result, setResult] = React.useState<TranscribeResult | null>(null);
  const [settings, setSettings] = React.useState<Settings>({
    modelDir: localStorage.getItem("ai-audio-model-dir") ?? "",
    modelId: localStorage.getItem("ai-audio-model-id") ?? "large-v3",
    language: "zh",
    segmentSeconds: 600,
    device: "cuda",
    computeType: "float16",
  });

  const selectedModel = modelStatus?.models.find((item) => item.id === settings.modelId);

  React.useEffect(() => {
    async function boot() {
      try {
        const [version, defaultDir] = await Promise.all([
          invoke<string>("engine_version"),
          invoke<string>("default_model_dir"),
        ]);
        const modelDir = settings.modelDir || defaultDir;
        setEngineVersion(version);
        setSettings((current) => ({ ...current, modelDir }));
        localStorage.setItem("ai-audio-model-dir", modelDir);
        await Promise.all([refreshGpu(), refreshModels(modelDir)]);
      } catch (error) {
        setMessage(error instanceof Error ? error.message : String(error));
      }
    }
    boot();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function refreshGpu() {
    setGpu(await invoke<GpuStatus>("gpu_status"));
  }

  async function refreshModels(modelDir = settings.modelDir) {
    const status = await invoke<ModelStatus>("model_status", { modelDir });
    setModelStatus(status);
  }

  async function chooseModelDir() {
    const dir = await open({ directory: true, multiple: false });
    if (!dir) return;
    setSettings((current) => ({ ...current, modelDir: dir }));
    localStorage.setItem("ai-audio-model-dir", dir);
    await refreshModels(dir);
  }

  async function chooseVideo() {
    setMessage("");
    const path = await open({
      multiple: false,
      filters: [{ name: "Video", extensions: ["mp4", "mkv", "mov", "webm", "avi", "flv"] }],
    });
    if (!path) return;
    const info = await invoke<VideoInfo>("probe_video", { video: path });
    setVideo(info);
    setResult(null);
  }

  async function downloadModel(modelId: string) {
    setDownloadBusy(modelId);
    setMessage("正在下载模型，请保持网络连接，large-v3 首次下载可能需要较长时间。");
    try {
      await invoke("download_model", { modelDir: settings.modelDir, modelId });
      await refreshModels();
      setMessage("模型下载完成。");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setDownloadBusy("");
    }
  }

  async function transcribe() {
    if (!video) {
      setMessage("请先选择视频文件。");
      return;
    }
    if (!selectedModel?.ready) {
      setPage("models");
      setMessage("当前模型不完整，请先下载或手动放入模型文件。");
      return;
    }
    setBusy(true);
    setResult(null);
    setMessage("正在转写，处理期间请不要关闭客户端。");
    try {
      const data = await invoke<TranscribeResult>("transcribe_video", {
        options: {
          video: video.path,
          modelDir: settings.modelDir,
          modelId: settings.modelId,
          language: settings.language,
          segmentSeconds: settings.segmentSeconds,
          device: settings.device,
          computeType: settings.computeType,
        },
      });
      setResult(data);
      setMessage("处理完成。");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  }

  function setStableMode(enabled: boolean) {
    setSettings((current) => ({
      ...current,
      segmentSeconds: enabled ? 300 : 600,
      computeType: enabled ? "int8_float16" : "float16",
    }));
  }

  function updateSetting<K extends keyof Settings>(key: K, value: Settings[K]) {
    setSettings((current) => {
      const next = { ...current, [key]: value };
      if (key === "modelId") {
        localStorage.setItem("ai-audio-model-id", String(value));
      }
      return next;
    });
  }

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
        {message && <div className="banner">{message}</div>}
        {page === "home" && (
          <Home
            engineVersion={engineVersion}
            gpu={gpu}
            modelStatus={modelStatus}
            selectedModel={selectedModel}
            lastOutput={result?.result.outputDir}
            onRefreshGpu={refreshGpu}
            onRefreshModels={() => refreshModels()}
            onOpenModels={() => setPage("models")}
          />
        )}
        {page === "tasks" && (
          <Tasks
            busy={busy}
            video={video}
            settings={settings}
            selectedModel={selectedModel}
            result={result}
            onChooseVideo={chooseVideo}
            onTranscribe={transcribe}
            onStableMode={setStableMode}
            onSetting={updateSetting}
          />
        )}
        {page === "models" && (
          <Models
            status={modelStatus}
            settings={settings}
            downloadBusy={downloadBusy}
            onChooseDir={chooseModelDir}
            onRefresh={() => refreshModels()}
            onDownload={downloadModel}
            onModel={(modelId) => updateSetting("modelId", modelId)}
          />
        )}
        {page === "help" && <Help />}
        {page === "updates" && <Updates />}
        {page === "donate" && <Donate />}
      </section>
    </main>
  );
}

function Home({
  engineVersion,
  gpu,
  modelStatus,
  selectedModel,
  lastOutput,
  onRefreshGpu,
  onRefreshModels,
  onOpenModels,
}: {
  engineVersion: string;
  gpu: GpuStatus | null;
  modelStatus: ModelStatus | null;
  selectedModel?: ModelItem;
  lastOutput?: string;
  onRefreshGpu: () => void;
  onRefreshModels: () => void;
  onOpenModels: () => void;
}) {
  const readyCount = modelStatus?.models.filter((item) => item.ready).length ?? 0;
  return (
    <section>
      <h1>Windows 便携版视频转写工具</h1>
      <p>本地免登录使用，选择视频后生成 SRT 字幕、Markdown 时间轴文稿、详细教程和实施方案。</p>
      <div className="grid">
        <InfoCard title="引擎" text={engineVersion ? `本地 engine ${engineVersion}` : "正在检查本地 engine"} />
        <InfoCard
          title="模型"
          text={selectedModel?.ready ? `${selectedModel.name} 已就绪` : `已就绪模型 ${readyCount} 个，请先准备模型`}
        />
        <InfoCard title="硬件" text={gpu?.available ? gpu.gpus.join(" / ") : "未检测到 NVIDIA GPU，可切换 CPU 模式"} />
      </div>
      <div className="actions">
        <button onClick={onRefreshGpu}>刷新硬件</button>
        <button onClick={onRefreshModels}>重新扫描模型</button>
        <button className="primary" onClick={onOpenModels}>模型管理</button>
      </div>
      {lastOutput && <PathBox title="最近输出目录" path={lastOutput} />}
    </section>
  );
}

function Tasks({
  busy,
  video,
  settings,
  selectedModel,
  result,
  onChooseVideo,
  onTranscribe,
  onStableMode,
  onSetting,
}: {
  busy: boolean;
  video: VideoInfo | null;
  settings: Settings;
  selectedModel?: ModelItem;
  result: TranscribeResult | null;
  onChooseVideo: () => void;
  onTranscribe: () => void;
  onStableMode: (enabled: boolean) => void;
  onSetting: <K extends keyof Settings>(key: K, value: Settings[K]) => void;
}) {
  const canRun = !!video && !!selectedModel?.ready && !busy;
  return (
    <section>
      <h1>转写任务</h1>
      <p>只显示原文件名、大小、格式和时长；不显示视频或图片预览。</p>
      <div className="task-layout">
        <div>
          <button className="primary" onClick={onChooseVideo} disabled={busy}>选择视频文件</button>
          {video ? (
            <div className="details">
              <div><strong>文件名</strong><span>{video.fileName}</span></div>
              <div><strong>格式</strong><span>{video.format}</span></div>
              <div><strong>大小</strong><span>{formatBytes(video.sizeBytes)}</span></div>
              <div><strong>时长</strong><span>{video.durationText}</span></div>
              <div><strong>路径</strong><span>{video.path}</span></div>
            </div>
          ) : (
            <div className="drop-zone">尚未选择视频</div>
          )}
        </div>
        <div className="settings-panel">
          <h2>参数</h2>
          <label>当前模型</label>
          <input value={selectedModel?.name ?? "模型未就绪"} disabled />
          <label>语言代码</label>
          <input value={settings.language} onChange={(event) => onSetting("language", event.target.value)} disabled={busy} />
          <label>切片秒数</label>
          <input
            type="number"
            min={60}
            max={600}
            step={60}
            value={settings.segmentSeconds}
            onChange={(event) => onSetting("segmentSeconds", Number(event.target.value))}
            disabled={busy}
          />
          <label>设备</label>
          <select value={settings.device} onChange={(event) => onSetting("device", event.target.value)} disabled={busy}>
            <option value="cuda">cuda</option>
            <option value="cpu">cpu</option>
            <option value="auto">auto</option>
          </select>
          <label>计算精度</label>
          <select value={settings.computeType} onChange={(event) => onSetting("computeType", event.target.value)} disabled={busy}>
            <option value="float16">float16</option>
            <option value="int8_float16">int8_float16</option>
            <option value="int8">int8</option>
            <option value="float32">float32</option>
          </select>
          <label className="checkbox-row">
            <input type="checkbox" onChange={(event) => onStableMode(event.target.checked)} disabled={busy} />
            稳定模式
          </label>
          <button className="primary wide" onClick={onTranscribe} disabled={!canRun}>
            {busy ? "正在转写..." : "开始转写并生成文档"}
          </button>
        </div>
      </div>
      {result && <ResultPanel result={result} />}
    </section>
  );
}

function ResultPanel({ result }: { result: TranscribeResult }) {
  return (
    <div className="settings-panel result-panel">
      <h2>输出文件</h2>
      <PathBox title="输出目录" path={result.result.outputDir} openable />
      <div className="file-grid">
        <PathBox title="SRT 字幕" path={result.result.srt} />
        <PathBox title="MD 时间轴文稿" path={result.result.transcriptMd} />
        <PathBox title="详细教程" path={result.result.tutorialMd} />
        <PathBox title="实施方案" path={result.result.implementationPlanMd} />
      </div>
      <h2>处理日志</h2>
      <ul className="log-list">
        {result.log.map((item, index) => (
          <li key={index}>{eventLabel(String(item.event ?? "event"))}</li>
        ))}
      </ul>
    </div>
  );
}

function Models({
  status,
  settings,
  downloadBusy,
  onChooseDir,
  onRefresh,
  onDownload,
  onModel,
}: {
  status: ModelStatus | null;
  settings: Settings;
  downloadBusy: string;
  onChooseDir: () => void;
  onRefresh: () => void;
  onDownload: (modelId: string) => void;
  onModel: (modelId: string) => void;
}) {
  return (
    <section>
      <h1>模型管理</h1>
      <p>首次使用必须准备 ASR 模型。可以软件内下载，也可以手动下载到指定目录后重新扫描。</p>
      <div className="settings-panel">
        <h2>模型目录</h2>
        <PathBox title="当前目录" path={settings.modelDir} />
        <button onClick={onChooseDir}>选择模型目录</button>
        <button onClick={onRefresh}>重新扫描</button>
      </div>
      <div className="model-list">
        {(status?.models ?? []).map((model) => (
          <article key={model.id} className={model.ready ? "card model-card ready" : "card model-card"}>
            <div className="model-head">
              <div>
                <h2>{model.name}</h2>
                <p>{model.purpose}</p>
              </div>
              <label className="radio-row">
                <input
                  type="radio"
                  checked={settings.modelId === model.id}
                  onChange={() => onModel(model.id)}
                />
                使用
              </label>
            </div>
            <p><strong>建议硬件：</strong>{model.hardware}</p>
            <p><strong>预计体积：</strong>{model.size}</p>
            <p><strong>目标目录：</strong>{model.targetDir}</p>
            {model.ready ? (
              <p className="status success">模型已就绪</p>
            ) : (
              <p className="status warning">缺失：{model.missingFiles.join(", ")}</p>
            )}
            <div className="actions">
              <button className="primary" onClick={() => onDownload(model.id)} disabled={!!downloadBusy}>
                {downloadBusy === model.id ? "下载中..." : "下载到指定目录"}
              </button>
              <a href={model.mirrorUrl} target="_blank" rel="noreferrer">镜像下载页</a>
              <a href={model.originalUrl} target="_blank" rel="noreferrer">Hugging Face</a>
            </div>
          </article>
        ))}
      </div>
      <div className="settings-panel">
        <h2>手动下载说明</h2>
        <p>进入模型下载页，把必需文件放到对应模型目录中，然后点击“重新扫描”。</p>
        <code>config.json, model.bin, preprocessor_config.json, tokenizer.json, vocabulary.json</code>
      </div>
    </section>
  );
}

function Help() {
  return (
    <section>
      <h1>使用帮助</h1>
      <div className="settings-panel">
        <h2>视频格式和时长</h2>
        <p>支持 mp4、mkv、mov、webm、avi、flv。0-60 分钟可直接处理，超过 2 小时建议按章节拆分。</p>
      </div>
      <div className="settings-panel">
        <h2>硬件建议</h2>
        <p>NVIDIA GPU 推荐使用 cuda + float16；显存压力大时使用稳定模式。CPU 可用但速度明显更慢。</p>
      </div>
      <div className="settings-panel">
        <h2>首次使用</h2>
        <p>先进入模型管理，下载一个 ASR 模型或手动放入模型文件。模型未就绪时无法开始转写。</p>
      </div>
      <div className="settings-panel">
        <h2>WebView2</h2>
        <p>Windows 11 通常已内置 WebView2。如客户端无法打开，请安装 Microsoft Edge WebView2 Runtime。</p>
      </div>
    </section>
  );
}

function Updates() {
  return (
    <section>
      <h1>版本更新</h1>
      <p>便携版当前不强制联网检查更新。后续商业版会接入云端版本检查、更新说明和下载入口。</p>
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

function PathBox({ title, path, openable = false }: { title: string; path: string; openable?: boolean }) {
  async function open() {
    await invoke("open_output_dir", { path });
  }
  return (
    <div className="path-box">
      <strong>{title}</strong>
      <span>{path}</span>
      {openable && <button onClick={open}>打开目录</button>}
    </div>
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
