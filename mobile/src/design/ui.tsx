import React from 'react';
import { Pressable, Text, View, ScrollView, TextInput, StyleSheet, Platform, useWindowDimensions, type ViewStyle, type StyleProp, type TextStyle } from 'react-native';
import { Image } from 'expo-image';
import { Feather } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { useApp } from '../data/store';

export const c = { bg:'#F7F8FA',paper:'#FFFFFF',ink:'#171B24',muted:'#757C8B',line:'#E6E9EF',blue:'#315EF5',blueSoft:'#EAF0FF',green:'#397D67',red:'#D34D59',soft:'#F0F2F6' };
export const font = Platform.select({web:'-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif',default:undefined});
export const textStyle:TextStyle = {fontFamily:font,color:c.ink,fontSize:15,lineHeight:23};
export const s=StyleSheet.create({
  row:{flexDirection:'row',alignItems:'center'},between:{flexDirection:'row',alignItems:'center',justifyContent:'space-between'},
  title:{...textStyle,fontSize:32,lineHeight:43,fontWeight:'600',letterSpacing:-1},h2:{...textStyle,fontSize:20,lineHeight:29,fontWeight:'600',letterSpacing:-0.5},
  body:{...textStyle},muted:{...textStyle,color:c.muted,fontSize:13,lineHeight:21},tiny:{...textStyle,color:c.muted,fontSize:11,lineHeight:17},
  label:{...textStyle,fontSize:13,fontWeight:'600'},rule:{height:1,backgroundColor:c.line},section:{marginTop:30},
  input:{...textStyle,backgroundColor:c.paper,borderWidth:1,borderColor:c.line,borderRadius:12,paddingHorizontal:15,paddingVertical:13,minHeight:50},
  shadow:{shadowColor:'#202C4B',shadowOffset:{width:0,height:8},shadowOpacity:0.07,shadowRadius:22,elevation:3}
});
export type IconName=React.ComponentProps<typeof Feather>['name'];
export function Icon({name,size=21,color=c.ink}:{name:IconName;size?:number;color?:string}) { return <Feather name={name} size={size} color={color} accessible={false}/>; }
export function tap() { if(Platform.OS!=='web' && useApp.getState().data.settings.haptics) void Haptics.selectionAsync().catch(()=>{}); }
export function Button({children,onPress,icon,secondary=false,disabled=false,testID,style}:{children:string;onPress:()=>void;icon?:IconName;secondary?:boolean;disabled?:boolean;testID?:string;style?:StyleProp<ViewStyle>}) {
  return <Pressable accessibilityRole="button" accessibilityState={{disabled}} accessibilityLabel={children} testID={testID} disabled={disabled} onPress={()=>{tap();onPress();}} style={({pressed})=>[{minHeight:50,paddingHorizontal:20,paddingVertical:13,borderRadius:14,backgroundColor:secondary?c.soft:c.blue,flexDirection:'row',alignItems:'center',justifyContent:'center',gap:8,opacity:disabled?0.45:pressed?0.75:1},style]}>
    {icon&&<Icon name={icon} size={18} color={secondary?c.ink:'#fff'}/>}<Text style={[s.label,{color:secondary?c.ink:'#fff',fontSize:15}]}>{children}</Text>
  </Pressable>;
}
export function IconButton({name,label,onPress,active=false,style}:{name:IconName;label:string;onPress:()=>void;active?:boolean;style?:StyleProp<ViewStyle>}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={()=>{tap();onPress();}} style={({pressed})=>[{width:44,height:44,borderRadius:22,alignItems:'center',justifyContent:'center',backgroundColor:active?c.blueSoft:pressed?c.soft:'transparent'},style]}><Icon name={name} color={active?c.blue:c.ink}/></Pressable>;
}
export function Chip({label,selected,onPress}:{label:string;selected:boolean;onPress:()=>void}) {
  return <Pressable accessibilityRole="button" accessibilityState={{selected}} accessibilityLabel={label} onPress={()=>{tap();onPress();}} style={{minHeight:44,paddingHorizontal:16,paddingVertical:11,borderRadius:24,backgroundColor:selected?c.ink:'transparent',justifyContent:'center'}}><Text style={[s.label,{color:selected?'#fff':c.muted}]}>{label}</Text></Pressable>;
}
export function Field({label,value,onChangeText,placeholder,multiline=false,keyboardType='default'}:{label:string;value:string;onChangeText:(value:string)=>void;placeholder?:string;multiline?:boolean;keyboardType?:React.ComponentProps<typeof TextInput>['keyboardType']}) {
  return <View style={{gap:9,marginBottom:22}}><Text style={s.label}>{label}</Text><TextInput accessibilityLabel={label} value={value} onChangeText={onChangeText} placeholder={placeholder} placeholderTextColor={c.muted} multiline={multiline} keyboardType={keyboardType} style={[s.input,multiline&&{minHeight:116,textAlignVertical:'top'}]}/></View>;
}
export function Photo({uri,name='',style,hidden=false}:{uri:string|null;name?:string;style?:StyleProp<ViewStyle>;hidden?:boolean}) {
  const source=uri==='demo:portrait'?require('../../assets/editorial-portrait.png'):uri?{uri}:undefined;
  return <View style={[{backgroundColor:uri?c.soft:'#E9EDF3',overflow:'hidden',alignItems:'center',justifyContent:'center'},style]}>
    {source&&!hidden?<Image source={source} style={StyleSheet.absoluteFill} contentFit="cover" contentPosition="top center" transition={180} accessibilityLabel={`${name}的照片`}/>:<View style={{alignItems:'center',gap:12}}><Text style={{fontSize:48,fontWeight:'200',color:'#9AA7BA',fontFamily:font}}>{hidden?'· ·':name.slice(0,1)}</Text></View>}
  </View>;
}
export function Avatar({uri,name,size=44,hidden=false}:{uri:string|null;name:string;size?:number;hidden?:boolean}) {return <Photo uri={uri} name={name} hidden={hidden} style={{width:size,height:size,borderRadius:size/2}}/>;}
export function SectionHeading({title,action,onPress}:{title:string;action?:string;onPress?:()=>void}) {return <View style={[s.between,{marginBottom:17}]}><Text style={s.h2}>{title}</Text>{action&&<Pressable accessibilityRole="button" onPress={onPress} style={[s.row,{minHeight:44,gap:5}]}><Text style={[s.muted,{color:c.blue}]}>{action}</Text><Icon name="arrow-up-right" size={15} color={c.blue}/></Pressable>}</View>;}
export function Empty({title,description,action,onPress,icon='layers'}:{title:string;description:string;action?:string;onPress?:()=>void;icon?:IconName}) {return <View style={{paddingVertical:54,alignItems:'center',gap:15,paddingHorizontal:20}}><View style={{backgroundColor:c.blueSoft,padding:20,borderRadius:28}}><Icon name={icon} size={30} color={c.blue}/></View><Text style={[s.h2,{textAlign:'center'}]}>{title}</Text><Text style={[s.muted,{textAlign:'center',maxWidth:300}]}>{description}</Text>{action&&onPress&&<Button onPress={onPress} style={{marginTop:7}}>{action}</Button>}</View>;}
export function Header({title,back=false,right}:{title?:string;back?:boolean;right?:React.ReactNode}) {
  const hidden=useApp(a=>a.hidden),setHidden=useApp(a=>a.setHidden),demo=useApp(a=>a.data.demo);
  return <View style={[s.between,{height:64,marginBottom:10}]}>
    {back?<View style={[s.row,{gap:5,flex:1}]}><IconButton name="arrow-left" label="返回" onPress={()=>router.canGoBack()?router.back():router.replace('/')}/><Text style={[s.label,{fontSize:17}]}>{title}</Text></View>:<View style={[s.row,{gap:10}]}><View style={{width:28,height:28,backgroundColor:c.blue,borderRadius:9,transform:[{rotate:'-8deg'}],alignItems:'center',justifyContent:'center'}}><Icon name="aperture" color="#fff" size={23}/></View><Text style={{fontFamily:font,fontSize:25,letterSpacing:-1.2,fontWeight:'800',color:c.ink}}>astra</Text>{demo&&<Text style={[s.tiny,{marginLeft:5}]}>示例</Text>}</View>}
    {right||<View style={s.row}><IconButton name={hidden?'eye-off':'eye'} label={hidden?'显示私人内容':'隐藏私人内容'} onPress={()=>setHidden(!hidden)}/><IconButton name="sliders" label="设置" onPress={()=>router.push('/settings')}/></View>}
  </View>;
}
export function Screen({children,back,title,right,scroll=true}:{children:React.ReactNode;back?:boolean;title?:string;right?:React.ReactNode;scroll?:boolean}) {
  const insets=useSafeAreaInsets();const {width}=useWindowDimensions();
  const pad=width<390?20:width>900?40:24;
  const content=<View style={{width:'100%',maxWidth:1040,alignSelf:'center',paddingHorizontal:pad,paddingTop:insets.top}}><Header back={back} title={title} right={right}/>{children}<View style={{height:40}}/></View>;
  return <View style={{flex:1,backgroundColor:c.bg}}>{scroll?<ScrollView keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false} contentContainerStyle={{paddingBottom:insets.bottom}}>{content}</ScrollView>:content}</View>;
}
export function Name({value,style}:{value:string;style?:StyleProp<TextStyle>}) {const hidden=useApp(a=>a.hidden);return <Text style={[s.body,style]}>{hidden?'已隐藏':value}</Text>;}
export function ErrorNote({message}:{message:string}) {return message?<View accessibilityRole="alert" style={{padding:14,borderRadius:12,backgroundColor:'#FDEEF0',marginBottom:16}}><Text style={[s.body,{color:c.red}]}>{message}</Text></View>:null;}
