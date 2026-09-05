import React from 'react';
import {View,Text,Pressable} from 'react-native';
import {router} from 'expo-router';
import {useApp} from '../data/store';
import {scoreAverage} from '../domain/model';
import {Screen,Avatar,Name,Empty,c,s} from '../design/ui';
export default function Ranking(){const {data,hidden}=useApp();const people=[...data.people].filter(p=>scoreAverage(p.scores)>0).sort((a,b)=>scoreAverage(b.scores)-scoreAverage(a.scores));return <Screen back title="偏爱排行"><Text style={[s.title,{marginTop:15}]}>你的心动，有迹可循。</Text><Text style={[s.muted,{marginTop:8,marginBottom:25}]}>按六维综合评分排列，仅你可见。</Text>{people.length?people.map((p,i)=><Pressable key={p.id} accessibilityRole="button" onPress={()=>router.push({pathname:'/person/[id]',params:{id:p.id}})} style={[s.row,{gap:17,paddingVertical:24,borderBottomWidth:1,borderBottomColor:c.line}]}><Text style={[s.h2,{color:i===0?c.blue:c.muted,width:29}]}>{String(i+1).padStart(2,'0')}</Text><Avatar uri={p.photo} name={p.name} hidden={hidden} size={55}/><View style={{flex:1,gap:5}}><Name value={p.name} style={s.h2}/><Text style={s.tiny}>{hidden?'已隐藏':p.tags.join(' / ')}</Text></View><Text style={[s.h2,{color:c.blue}]}>{scoreAverage(p.scores).toFixed(1)}</Text></Pressable>):<Empty title="偏爱，由你定义" description="为人物填写评分，这里就会出现你的私人排行。"/>}</Screen>;}
