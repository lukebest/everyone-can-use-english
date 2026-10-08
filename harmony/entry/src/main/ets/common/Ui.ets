import { promptAction } from '@kit.ArkUI';

export function toast(message: string): void {
  promptAction.showToast({ message: message, duration: 2000 });
}

export function errorText(err: Object): string {
  if (err instanceof Error) {
    return err.message;
  }
  return '请求失败';
}
