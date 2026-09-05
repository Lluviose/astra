import { create } from 'zustand';
import { emptyData, type Data } from '../domain/model';
import { loadData, saveData } from './database';

type Store = {
  data: Data; ready: boolean; error: string; hidden: boolean; toast: string; unlocked: boolean;
  hydrate: () => Promise<void>; mutate: (change: (data:Data) => Data) => Promise<void>;
  setHidden: (value:boolean) => void; notify:(message:string) => void;
};
let pending: Promise<void> = Promise.resolve();
let toastTimer: ReturnType<typeof setTimeout>;
export const useApp = create<Store>((set,get) => ({
  data:emptyData(),ready:false,error:'',hidden:false,toast:'',unlocked:false,
  hydrate:async () => { try { const data=await loadData(); set({data,ready:true,hidden:data.settings.maskOnLaunch,error:''}); } catch { set({error:'暂时无法读取档案，请重试。'}); } },
  mutate:change => {
    const operation = pending.catch(() => {}).then(async () => {
      if (!get().ready) throw new Error('档案还未加载完成');
      const data = change(get().data);
      await saveData(data);
      set({data});
    });
    pending=operation;
    return operation;
  },
  setHidden:hidden => set({hidden}),
  notify:toast => { clearTimeout(toastTimer); set({toast}); toastTimer=setTimeout(() => set({toast:''}),2600); }
}));
export function newId() { return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2,11)}`; }
