import * as ImagePicker from "expo-image-picker";
export async function pickPhoto(): Promise<string | null> {
  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ["images"],
    allowsEditing: false,
  });
  if (result.canceled) return null;
  const response = await fetch(result.assets[0].uri);
  const blob = await response.blob();
  if (blob.size > 3 * 1024 * 1024)
    throw new Error("网页预览请选择 3 MB 以内的照片；iOS 版保存本地原图。");
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(new Error("无法读取照片"));
    reader.readAsDataURL(blob);
  });
}
