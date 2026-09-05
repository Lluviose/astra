import React from 'react';
import { View,Text,Pressable,useWindowDimensions } from 'react-native';
import { Tabs,router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { c,s,Icon,Button,type IconName,tap } from '../../design/ui';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';

function Navigation({state,navigation}:BottomTabBarProps){
  const insets=useSafeAreaInsets();
  const items:[string,string,IconName][]=[['index','后宫','grid'],['journal','战绩','align-left'],['hall','殿堂','hexagon']];
  return <View style={{backgroundColor:'#fff',borderTopWidth:1,borderTopColor:c.line,paddingBottom:Math.max(insets.bottom,12),paddingTop:11}}><View style={{maxWidth:700,width:'100%',alignSelf:'center',flexDirection:'row',paddingHorizontal:18,alignItems:'center',gap:8}}>
    {items.map(([name,label,icon])=>{const route=state.routes.find(r=>r.name===name);if(!route)return null;const active=state.routes[state.index].key===route.key;return <Pressable key={name} accessibilityRole="tab" accessibilityLabel={label} accessibilityState={{selected:active}} onPress={()=>{tap();const event=navigation.emit({type:'tabPress',target:route.key,canPreventDefault:true});if(!event.defaultPrevented)navigation.navigate(name);}} style={{flex:1,minHeight:50,alignItems:'center',justifyContent:'center',gap:4}}><Icon name={icon} size={21} color={active?c.blue:c.muted}/><Text style={[s.tiny,{color:active?c.blue:c.muted,fontWeight:active?'700':'400'}]}>{label}</Text></Pressable>;})}
    <Pressable accessibilityRole="button" accessibilityLabel="新增记录" onPress={()=>router.push('/record')} style={{width:49,height:49,borderRadius:17,backgroundColor:c.blue,alignItems:'center',justifyContent:'center',marginLeft:10}}><Icon name="plus" size={24} color="#fff"/></Pressable>
  </View></View>;
}
export default function TabLayout(){return <Tabs tabBar={props=><Navigation {...props}/>} screenOptions={{headerShown:false,animation:'fade'}}><Tabs.Screen name="index"/><Tabs.Screen name="journal"/><Tabs.Screen name="hall"/></Tabs>;}
