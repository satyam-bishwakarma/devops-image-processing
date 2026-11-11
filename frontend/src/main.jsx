import { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';

function useImageUrl(image) {
  const [url, setUrl] = useState(null);
  useEffect(() => {
    const next = image ? URL.createObjectURL(image) : null;
    setUrl(next);
    return () => { if (next) URL.revokeObjectURL(next); };
  }, [image]);
  return url;
}

function App() {
  const [file, setFile] = useState(null);
  const [result, setResult] = useState(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const [mode, setMode] = useState('original');
  const originalUrl = useImageUrl(file);
  const resultUrl = useImageUrl(result);

  async function processImage(event) {
    event.preventDefault();
    if (!file || pending) return;
    const form = new FormData(event.currentTarget);
    const params = new URLSearchParams();
    if (mode !== 'original') {
      params.set('width', form.get('width'));
      params.set('height', form.get('height'));
      params.set('crop', String(mode === 'crop'));
    }
    setPending(true);
    setError('');
    setResult(null);
    try {
      const response = await fetch('/api/process?' + params.toString(), { method: 'POST', body: file });
      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        throw new Error(body.detail || 'Could not process the image.');
      }
      setResult(await response.blob());
    } catch (failure) {
      setError(failure.message);
    } finally {
      setPending(false);
    }
  }

  return (
    <main>
      <h1>Image Processing</h1>
      <form onSubmit={processImage}>
        <label htmlFor="image">Choose an image</label>
        <small>JPEG, PNG or WebP · Up to 8 MiB and 16 megapixels</small>
        <input id="image" type="file" accept="image/jpeg,image/png,image/webp"
          disabled={pending} onChange={event => {
            setFile(event.target.files[0] || null);
            setResult(null);
            setError('');
          }} />
        <fieldset disabled={pending}>
          <legend>Output size</legend>
          <select aria-label="Output size" value={mode} onChange={event => setMode(event.target.value)}>
            <option value="original">Original dimensions</option>
            <option value="fit">Fit within dimensions</option>
            <option value="crop">Crop to dimensions</option>
          </select>
          {mode !== 'original' && <>
            <label>Width (px)<input name="width" type="number" min="1" max="4000" defaultValue="800" required /></label>
            <label>Height (px)<input name="height" type="number" min="1" max="4000" defaultValue="600" required /></label>
          </>}
        </fieldset>
        <button disabled={!file || pending}>{pending ? 'Processing…' : 'Convert to PNG'}</button>
        {error && <p role="alert">{error}</p>}
      </form>
      <div className="previews">
        <section>
          <h2>Original</h2>
          {originalUrl ? <img src={originalUrl} alt="Selected image" /> : <p>Choose an image to preview it.</p>}
        </section>
        <section>
          <h2>Processed</h2>
          {resultUrl ? <>
            <img src={resultUrl} alt="Processed image" />
            <a href={resultUrl} download="processed.png">Download PNG</a>
          </> : <p aria-live="polite">{pending ? 'Processing image…' : 'The PNG will appear here.'}</p>}
        </section>
      </div>
    </main>
  );
}

createRoot(document.getElementById('root')).render(<App />);
