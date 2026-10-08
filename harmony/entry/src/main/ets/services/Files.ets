import { fileIo, picker } from '@kit.CoreFileKit';
import { getContext } from '../common/AppContext';

export function baseName(uri: string): string {
  const parts = uri.split('/');
  let name = parts.length > 0 ? parts[parts.length - 1] : 'media';
  const query = name.indexOf('?');
  if (query >= 0) {
    name = name.substring(0, query);
  }
  try {
    name = decodeURIComponent(name);
  } catch (e) {
    return name;
  }
  if (name.length === 0) {
    return 'media';
  }
  return name;
}

export function mediaKind(name: string): string {
  const lower = name.toLowerCase();
  if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.mov') || lower.endsWith('.webm')) {
    return 'video';
  }
  return 'audio';
}

export function ensureDir(dir: string): void {
  try {
    fileIo.mkdirSync(dir, true);
  } catch (e) {
    return;
  }
}

export function copyInto(uri: string, folder: string): string {
  const dir = getContext().filesDir + '/' + folder;
  ensureDir(dir);
  const destPath = dir + '/' + Date.now().toString() + '-' + baseName(uri);
  const src = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  const dest = fileIo.openSync(destPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
  fileIo.copyFileSync(src.fd, dest.fd);
  fileIo.closeSync(src);
  fileIo.closeSync(dest);
  return destPath;
}

export function readText(path: string): string {
  return fileIo.readTextSync(path);
}

export async function pickFile(): Promise<string> {
  const documentPicker = new picker.DocumentViewPicker();
  const options = new picker.DocumentSelectOptions();
  options.maxSelectNumber = 1;
  const uris = await documentPicker.select(options);
  if (uris.length === 0) {
    return '';
  }
  return uris[0];
}
