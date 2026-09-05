import React from 'react';
import {View,Text,Pressable,useWindowDimensions} from 'react-native';
import {router} from 'expo-router';
import Svg,{Circle,Path} from 'react-native-svg';
import {useApp} from '../data/store';
import {summary} from '../domain/model';
import {Screen,Icon,SectionHeading,c,s,type IconName} from '../design/ui';

export default function HallScreen(){
  const data=useApp(a=>a.data),hidden=useApp(a=>a.hidden),stats=summary(data);
  const {width}=useWindowDimensions(),wide=width>700;
  const milestones:[string,string,IconName,boolean][]=[['第一篇','故事的开始','feather',data.entries.length>0],['再一次','十次相处','repeat',data.entries.length>=10],['远方','三个城市','compass',stats.cities.length>=3],['长篇','三十次相处','book-open',data.entries.length>=30]];
  const max=Math.max(1,...stats.months.map(m=>m.count));
  return <Screen>
    <View style={{marginTop:14,marginBottom:26}}><Text style={s.title}>属于你的轨迹。</Text><Text style={[s.muted,{marginTop:7}]}>{data.settings.title}</Text></View>
    <View style={{backgroundColor:c.ink,borderRadius:20,padding:26,overflow:'hidden'}}>
      <Svg width="200" height="200" style={{position:'absolute',right:-50,top:-36}}><Circle cx="100" cy="100" r="72" fill="none" stroke="#39465F" strokeWidth="1"/><Circle cx="100" cy="100" r="47" fill="none" stroke="#39465F" strokeWidth="1"/><Path d="M24 128L144 26M36 175L184 53" stroke="#39465F" strokeWidth="1"/><Circle cx="64" cy="94" r="5" fill="#7C9EFF"/></Svg>
      <View style={[s.row,{gap:7}]}><View style={{width:6,height:6,backgroundColor:'#8AA7FF',borderRadius:3}}/><Text style={[s.tiny,{color:'#C7D1E3',letterSpacing:1}]}>你的私人殿堂</Text></View>
      <View style={[s.row,{alignItems:'baseline',gap:12,marginTop:21}]}><Text style={{fontSize:64,lineHeight:75,fontWeight:'300',color:'#fff',letterSpacing:-3,fontVariant:['tabular-nums']}}>{String(data.entries.length).padStart(2,'0')}</Text><Text style={[s.body,{color:'#A9B5CA'}]}>次相处</Text></View>
      <View style={{height:1,backgroundColor:'#394150',marginVertical:21}}/>
      <View style={s.row}>{[[stats.collectionCount,'后宫人物'],[stats.intimateCount,'亲密记录'],[stats.cities.length,'足迹城市']].map(([value,label])=><View key={label} style={{flex:1,gap:5}}><Text style={{fontSize:24,color:'#fff',fontWeight:'500'}}>{value}</Text><Text style={[s.tiny,{color:'#A9B5CA'}]}>{label}</Text></View>)}</View>
    </View>
    <View style={{flexDirection:wide?'row':'column',gap:wide?36:0}}><View style={{flex:1,marginTop:29}}><SectionHeading title="相处的节奏"/><View style={{flexDirection:'row',height:128,gap:16,alignItems:'flex-end'}}>{stats.months.map(m=><Pressable key={m.key} accessibilityRole="button" accessibilityLabel={`${m.label}，${m.count}条记录`} onPress={()=>router.push({pathname:'/journal',params:{month:m.key}})} style={{flex:1,alignItems:'center',gap:8}}><Text style={s.tiny}>{m.count}</Text><View style={{width:'100%',maxWidth:42,height:Math.max(4,m.count/max*83),borderRadius:6,backgroundColor:m.key===stats.months[5].key?c.blue:'#D7DFEF'}}/><Text style={s.tiny}>{m.label}</Text></Pressable>)}</View></View>
    <View style={{flex:1,marginTop:29}}><SectionHeading title="小小里程碑"/><View style={{flexDirection:'row',flexWrap:'wrap',gap:12}}>{milestones.map(([title,desc,icon,active])=><View key={title} style={{width:'47%',backgroundColor:active?'#fff':'#F0F2F5',borderRadius:14,padding:16,opacity:active?1:0.6}}><Icon name={icon} color={active?c.blue:c.muted}/><Text style={[s.label,{marginTop:12}]}>{title}</Text><Text style={[s.tiny,{marginTop:3}]}>{active?desc:'尚未解锁 · '+desc}</Text></View>)}</View></View></View>
    <View style={{marginTop:26}}>{[['偏爱排行','由你的六维评分排列','bar-chart-2','/ranking'],['足迹','每一站，都有故事','map','/footprints']].map(([title,description,icon,path])=><Pressable key={title} accessibilityRole="button" onPress={()=>router.push(path as '/ranking'|'/footprints')} style={[s.row,{gap:16,paddingVertical:22,borderBottomWidth:1,borderBottomColor:c.line}]}><Icon name={icon as IconName}/><View style={{flex:1}}><Text style={s.label}>{title}</Text><Text style={[s.tiny,{marginTop:4}]}>{description}</Text></View><Icon name="arrow-up-right" size={19} color={c.muted}/></Pressable>)}</View>
  </Screen>;
}
