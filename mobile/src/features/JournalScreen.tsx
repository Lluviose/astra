import React,{useState} from 'react';
import {View,Text,TextInput,Pressable,ScrollView} from 'react-native';
import {router,useLocalSearchParams} from 'expo-router';
import {useApp} from '../data/store';
import {filterEntries,kindLabels,localDate} from '../domain/model';
import {Screen,Avatar,Name,Icon,Chip,Empty,c,s} from '../design/ui';

export default function JournalScreen(){
  const {month:requestedMonth}=useLocalSearchParams<{month?:string}>();
  const {data,hidden,mutate,notify}=useApp();
  const [query,setQuery]=useState(''),[kind,setKind]=useState('all'),[person,setPerson]=useState('all'),[thisMonth,setThisMonth]=useState(false);
  const month=thisMonth?localDate().slice(0,7):requestedMonth||'all';
  const entries=filterEntries(data,query,kind,person,month);
  const followups=data.entries.filter(e=>e.followUp&&!e.completed);
  async function complete(id:string){try{await mutate(d=>({...d,entries:d.entries.map(e=>e.id===id?{...e,completed:!e.completed}:e)}));notify('跟进状态已更新');}catch{notify('保存失败，请重试');}}
  return <Screen>
    <View style={[s.between,{marginTop:14,marginBottom:25}]}><View><Text style={s.title}>每一次，都算数。</Text><Text style={[s.muted,{marginTop:7}]}>战绩 · {data.entries.length} 个相处片刻</Text></View><Icon name="calendar" size={25} color={c.muted}/></View>
    <View style={[s.row,{backgroundColor:'#ECEFF4',borderRadius:13,paddingHorizontal:14,gap:10,marginBottom:16}]}><Icon name="search" size={18} color={c.muted}/><TextInput accessibilityLabel="搜索战绩" placeholder="搜索人物、地点或记忆" placeholderTextColor={c.muted} value={query} onChangeText={setQuery} style={[s.body,{flex:1,minHeight:49,paddingVertical:12}]}/>{query&&<Pressable accessibilityRole="button" accessibilityLabel="清空搜索" onPress={()=>setQuery('')} style={{padding:10}}><Icon name="x" size={15}/></Pressable>}</View>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap:3,marginBottom:10}}>{[['all','全部'],['intimacy','亲密'],['date','约会'],['missed','未发生']].map(([key,label])=><Chip key={key} label={label} selected={kind===key} onPress={()=>setKind(key)}/>)}<Chip label="本月" selected={thisMonth} onPress={()=>setThisMonth(!thisMonth)}/></ScrollView>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap:14,marginBottom:25}}><Pressable accessibilityRole="button" onPress={()=>setPerson('all')} style={{paddingVertical:10,borderBottomWidth:person==='all'?2:0,borderBottomColor:c.blue}}><Text style={[s.muted,{color:person==='all'?c.blue:c.muted}]}>所有人物</Text></Pressable>{data.people.map(p=><Pressable key={p.id} accessibilityRole="button" onPress={()=>setPerson(p.id)} style={{paddingVertical:10,borderBottomWidth:person===p.id?2:0,borderBottomColor:c.blue}}><Name value={p.name} style={[s.muted,{color:person===p.id?c.blue:c.muted}]}/></Pressable>)}</ScrollView>
    {followups.length>0&&!query&&kind==='all'&&person==='all'&&!thisMonth&&<View style={{backgroundColor:c.blueSoft,borderRadius:14,padding:18,marginBottom:25}}><View style={[s.row,{gap:8,marginBottom:10}]}><Icon name="clock" color={c.blue} size={17}/><Text style={[s.label,{color:c.blue}]}>还想再联系 · {followups.length}</Text></View>{followups.slice(0,3).map(e=><View key={e.id} style={[s.between,{gap:12}]}><Name value={data.people.find(p=>p.id===e.personId)?.name||''}/><Pressable accessibilityRole="button" accessibilityLabel="完成跟进" onPress={()=>void complete(e.id)} style={{minHeight:44,justifyContent:'center'}}><Text style={[s.label,{color:c.blue}]}>标记完成</Text></Pressable></View>)}</View>}
    <View style={[s.between,{marginBottom:20}]}><Text style={s.label}>{month==='all'?'所有时间':month.replace('-',' 年 ')+' 月'}</Text><View style={[s.row,{gap:14}]}><Text style={s.tiny}>{entries.length} 条记录</Text>{(query||kind!=='all'||person!=='all'||thisMonth||requestedMonth)&&<Pressable accessibilityRole="button" onPress={()=>{setQuery('');setKind('all');setPerson('all');setThisMonth(false);router.setParams({month:''});}} style={{minHeight:44,justifyContent:'center'}}><Text style={[s.tiny,{color:c.blue}]}>重置筛选</Text></Pressable>}</View></View>
    {entries.length===0?<Empty title="这里还很安静" description="记录一个片刻，或者试试其他筛选条件。" action="记一笔" onPress={()=>router.push('/record')} icon="edit-3"/>:entries.map((entry,index)=>{
      const p=data.people.find(p=>p.id===entry.personId)!;const showMonth=index===0||entries[index-1].date.slice(0,7)!==entry.date.slice(0,7);
      return <View key={entry.id}>{showMonth&&<Text style={[s.tiny,{letterSpacing:1,marginBottom:20,marginTop:index?20:0}]}>{entry.date.slice(0,7).replace('-',' / ')}</Text>}
        <View style={{flexDirection:'row',gap:16}}><View style={{width:30,alignItems:'center'}}><Text style={[s.h2,{fontSize:23}]}>{entry.date.slice(8)}</Text><View style={{width:1,flex:1,backgroundColor:c.line,marginTop:10,marginBottom:9}}/></View><View style={{flex:1,paddingBottom:27}}>
          <Pressable accessibilityRole="button" accessibilityLabel={hidden?'编辑私人记录':`编辑记录：${entry.title}`} onPress={()=>router.push({pathname:'/record',params:{id:entry.id}})}><View style={[s.row,{gap:9,marginBottom:10}]}><Avatar uri={p.photo} name={p.name} hidden={hidden} size={27}/><Name value={p.name} style={s.label}/><Text style={[s.tiny,{marginLeft:'auto',color:entry.kind==='intimacy'?c.blue:c.muted}]}>{kindLabels[entry.kind]}</Text></View><Text style={[s.h2,{fontSize:18,lineHeight:27}]}>{hidden?'私人记录':entry.title}</Text><Text numberOfLines={2} style={[s.muted,{marginTop:6}]}>{hidden?'内容已隐藏':entry.note}</Text><View style={[s.row,{gap:4,marginTop:11}]}><Icon name="map-pin" size={12} color={c.muted}/><Text style={s.tiny}>{hidden?'已隐藏':entry.city||'地点待补充'}</Text></View></Pressable>
          {entry.followUp&&entry.completed&&<Pressable accessibilityRole="button" accessibilityLabel="撤销跟进完成" onPress={()=>void complete(entry.id)} style={{minHeight:44,justifyContent:'center'}}><Text style={[s.tiny,{color:c.green}]}>已跟进 · 点此撤销</Text></Pressable>}
        </View></View>
      </View>;
    })}
  </Screen>;
}
