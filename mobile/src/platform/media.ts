import { Directory, File, Paths } from 'expo-file-system';
import * as ImagePicker from 'expo-image-picker';
import { newId } from '../data/store';

export async function pickPhoto(): Promise<string | null> {
  const result = await ImagePicker.launchImageLibraryAsync({mediaTypes:['images'],allowsEditing:false,quality:1});
  if (result.canceled) return null;
  const folder=new Directory(Paths.document,'AstraMedia');
  folder.create({idempotent:true,intermediates:true});
  const source=new File(result.assets[0].uri);
  const target=new File(folder,`${newId()}${source.extension || '.jpg'}`);
  source.copy(target);
  return target.uri;
}
