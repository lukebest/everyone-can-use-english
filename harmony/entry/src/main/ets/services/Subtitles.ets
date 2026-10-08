export class Cue {
  startMs: number = 0;
  endMs: number = 0;
  text: string = '';
}

function pad3(frac: string): string {
  let out = frac;
  while (out.length < 3) {
    out = out + '0';
  }
  return out.substring(0, 3);
}

function parseClock(raw: string): number {
  const text = raw.trim().replace('.', ',');
  const parts = text.split(':');
  if (parts.length < 2) {
    return 0;
  }
  let hours = 0;
  let minutes = 0;
  let secPart = '';
  if (parts.length >= 3) {
    hours = Number.parseInt(parts[0]);
    minutes = Number.parseInt(parts[1]);
    secPart = parts[2];
  } else {
    minutes = Number.parseInt(parts[0]);
    secPart = parts[1];
  }
  const secBits = secPart.split(',');
  const seconds = Number.parseInt(secBits[0]);
  let ms = 0;
  if (secBits.length > 1) {
    ms = Number.parseInt(pad3(secBits[1]));
  }
  if (Number.isNaN(hours) || Number.isNaN(minutes) || Number.isNaN(seconds) || Number.isNaN(ms)) {
    return 0;
  }
  return ((hours * 60 + minutes) * 60 + seconds) * 1000 + ms;
}

function stripTags(line: string): string {
  let out = '';
  let skip = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line.substring(i, i + 1);
    if (ch === '<') {
      skip = true;
    } else if (ch === '>') {
      skip = false;
    } else if (!skip) {
      out = out + ch;
    }
  }
  return out;
}

export function parseSubtitles(raw: string): Cue[] {
  const normalized = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const blocks = normalized.split('\n\n');
  const cues: Cue[] = [];
  for (let i = 0; i < blocks.length; i++) {
    const lines = blocks[i].split('\n');
    let timeLine = '';
    let textStart = 0;
    for (let j = 0; j < lines.length; j++) {
      if (lines[j].indexOf('-->') >= 0) {
        timeLine = lines[j];
        textStart = j + 1;
        break;
      }
    }
    if (timeLine.length === 0) {
      continue;
    }
    const times = timeLine.split('-->');
    if (times.length < 2) {
      continue;
    }
    const cue = new Cue();
    cue.startMs = parseClock(times[0]);
    const endBits = times[1].trim().split(' ');
    cue.endMs = parseClock(endBits[0]);
    let text = '';
    for (let j = textStart; j < lines.length; j++) {
      const line = lines[j].trim();
      if (line.length === 0 || line.indexOf('NOTE') === 0 || line === 'WEBVTT') {
        continue;
      }
      if (text.length > 0) {
        text = text + ' ';
      }
      text = text + stripTags(line);
    }
    cue.text = text.trim();
    if (cue.text.length > 0 && cue.endMs > cue.startMs) {
      cues.push(cue);
    }
  }
  return cues;
}
