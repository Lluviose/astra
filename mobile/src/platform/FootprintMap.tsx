import React,{useRef} from 'react';
import {View} from 'react-native';
import MapView,{Marker} from 'react-native-maps';
import {findCity,mapCoordinate} from '../domain/locations';
export default function FootprintMap({cities}:{cities:string[]}){
  const map=useRef<MapView>(null);
  const points=cities.flatMap(name=>{const c=findCity(name);return c?[{name,...mapCoordinate(c.lat,c.lon)}]:[];});
  return <View style={{height:300,borderRadius:18,overflow:'hidden',marginBottom:25}}><MapView ref={map} style={{flex:1}} initialRegion={{latitude:32,longitude:112,latitudeDelta:26,longitudeDelta:30}} userInterfaceStyle="light" showsUserLocation={false} onMapReady={()=>{if(points.length)map.current?.fitToCoordinates(points,{edgePadding:{top:55,bottom:55,left:55,right:55},animated:false});}}>{points.map(p=><Marker key={p.name} coordinate={p} title={p.name} pinColor="#315EF5"/>)}</MapView></View>;
}
