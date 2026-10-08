import { common } from '@kit.AbilityKit';

let abilityContext: common.UIAbilityContext | null = null;

export function setContext(context: common.UIAbilityContext): void {
  abilityContext = context;
}

export function getContext(): common.UIAbilityContext {
  if (abilityContext === null) {
    throw new Error('context missing');
  }
  return abilityContext;
}
