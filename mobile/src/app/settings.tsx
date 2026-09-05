import React,{useState} from 'react';
import {View,Text,Switch,Platform,Pressable} from 'react-native';
import {router} from 'expo-router';
import * as LocalAuthentication from 'expo-local-authentication';
import {useApp} from '../data/store';
import {emptyData,type Settings} from '../domain/model';
import {demoData} from '../domain/demo';
import {Screen,Field,Button,ErrorNote,Icon,c,s} from '../design/ui';
import Confirm from '../design/Confirm';

export default function SettingsScreen(){
  const {data,mutate,notify,setHidden}=useApp();const [title,setTitle]=useState(data.settings.title),[error,setError]=useState(''),[busy,setBusy]=useState(false),[reset,setReset]=useState(false);
  async function update(patch:Partial<Settings>){setBusy(true);setError('');try{await mutate(d=>({...d,settings:{...d.settings,...patch}}));return true;}catch{setError('设置未能保存，请重试');return false;}finally{setBusy(false);}}
  async function appLock(value:boolean){if(value){if(Platform.OS==='web'){setError('请在 iOS 应用中启用设备解锁。');return;}if(!await LocalAuthentication.isEnrolledAsync()){setError('请先在设备设置中配置面容 ID 或触控 ID。');return;}const result=await LocalAuthentication.authenticateAsync({promptMessage:'启用 Astra 解锁保护'});if(!result.success)return;useApp.setState({unlocked:true});}await update({appLock:value});}
  async function loadDemo(){setBusy(true);try{await mutate(()=>demoData());setHidden(false);notify('已载入虚构示例');router.replace('/');}catch{setError('示例未能载入');}finally{setBusy(false);}}
  async function clear(){setBusy(true);try{await mutate(()=>emptyData());setHidden(false);setReset(false);notify('已开始空白档案');router.replace('/');}catch{setError('未能清空，请重试');setReset(false);}finally{setBusy(false);}}
  return <Screen back title="设置"><View style={{maxWidth:640,width:'100%',alignSelf:'center'}}><Text style={[s.title,{marginTop:13,marginBottom:28}]}>保持你的方式。</Text><ErrorNote message={error}/><Field label="殿堂寄语" value={title} onChangeText={setTitle} placeholder="写一句属于你的话"/><Button secondary onPress={()=>void update({title:title.trim()||'把心动，留给自己。'}).then(success=>{if(success)notify('寄语已保存');})} disabled={busy}>保存寄语</Button>
    <Text style={[s.h2,{marginTop:34,marginBottom:12}]}>隐私与体验</Text>
    {[
      {label:'设备解锁',description:'打开应用时验证身份',value:data.settings.appLock,change:(value:boolean)=>void appLock(value)},
      {label:'启动时隐藏内容',description:'同时隐藏代号、照片与记录',value:data.settings.maskOnLaunch,change:(value:boolean)=>void update({maskOnLaunch:value})},
      {label:'触感反馈',description:'轻触之间，恰到好处',value:data.settings.haptics,change:(value:boolean)=>void update({haptics:value})}
    ].map(item=><View key={item.label} style={[s.between,{paddingVertical:21,borderBottomWidth:1,borderBottomColor:c.line,gap:20}]}><View style={{flex:1}}><Text style={s.body}>{item.label}</Text><Text style={[s.tiny,{marginTop:5}]}>{item.description}</Text></View><Switch accessibilityLabel={item.label} value={item.value} onValueChange={item.change} disabled={busy} trackColor={{true:c.blue}}/></View>)}
    <View style={{marginTop:34}}><Text style={s.h2}>开始体验</Text><Text style={[s.muted,{marginTop:9,marginBottom:18}]}>示例中的人物、照片和故事均为虚构。</Text>{data.people.length===0&&<Button secondary onPress={()=>void loadDemo()} disabled={busy}>载入示例内容</Button>}<Pressable accessibilityRole="button" onPress={()=>setReset(true)} style={{paddingVertical:22,minHeight:52}}><Text style={[s.label,{color:c.red}]}>清空并开始自己的档案</Text></Pressable></View>
    <View style={{marginTop:25,paddingVertical:25,borderTopWidth:1,borderTopColor:c.line,gap:7}}><Text style={[s.label,{letterSpacing:1}]}>ASTRA  2.0</Text><Text style={s.tiny}>你的故事，留在你手中。</Text></View>
    <Confirm visible={reset} title="开始空白档案？" message="当前版本的全部人物和记录将被清空。" onCancel={()=>setReset(false)} onConfirm={()=>void clear()} busy={busy}/>
  </View></Screen>;
}
