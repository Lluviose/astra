import React from "react";
import {
  Pressable,
  Text,
  View,
  ScrollView,
  TextInput,
  StyleSheet,
  Platform,
  Keyboard,
  useWindowDimensions,
  type ViewStyle,
  type StyleProp,
  type TextStyle,
} from "react-native";
import { Image } from "expo-image";
import { Feather } from "@expo/vector-icons";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { router } from "expo-router";
import * as Haptics from "expo-haptics";
import { useApp } from "../data/store";

export const c = {
  bg: "#F6F6F3",
  paper: "#FFFFFF",
  ink: "#171B24",
  muted: "#697181",
  line: "#E1E3DF",
  blue: "#315EF5",
  blueSoft: "#EAF0FF",
  green: "#397D67",
  red: "#D34D59",
  soft: "#F0F2F6",
};
export const font = Platform.select({
  web: '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif',
  default: undefined,
});
export const textStyle: TextStyle = {
  fontFamily: font,
  color: c.ink,
  fontSize: 15,
  lineHeight: 23,
};
export const s = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center" },
  between: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  title: {
    ...textStyle,
    fontSize: 34,
    lineHeight: 44,
    fontWeight: "500",
    letterSpacing: -1,
  },
  h2: {
    ...textStyle,
    fontSize: 20,
    lineHeight: 29,
    fontWeight: "600",
    letterSpacing: -0.5,
  },
  body: { ...textStyle },
  muted: { ...textStyle, color: c.muted, fontSize: 13, lineHeight: 21 },
  tiny: { ...textStyle, color: c.muted, fontSize: 12, lineHeight: 18 },
  label: { ...textStyle, fontSize: 13, fontWeight: "600" },
  rule: { height: 1, backgroundColor: c.line },
  section: { marginTop: 30 },
  input: {
    ...textStyle,
    backgroundColor: c.paper,
    borderWidth: 1,
    borderColor: c.line,
    borderRadius: 10,
    paddingHorizontal: 16,
    paddingVertical: 15,
    minHeight: 54,
  },
  shadow: {
    shadowColor: "#202C4B",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.07,
    shadowRadius: 22,
    elevation: 3,
  },
});
export type IconName = React.ComponentProps<typeof Feather>["name"];
export function Icon({
  name,
  size = 21,
  color = c.ink,
}: {
  name: IconName;
  size?: number;
  color?: string;
}) {
  return <Feather name={name} size={size} color={color} accessible={false} />;
}
export function tap() {
  if (Platform.OS !== "web" && useApp.getState().data.settings.haptics)
    void Haptics.selectionAsync().catch(() => {});
}
export function Button({
  children,
  onPress,
  icon,
  secondary = false,
  disabled = false,
  testID,
  style,
}: {
  children: string;
  onPress: () => void;
  icon?: IconName;
  secondary?: boolean;
  disabled?: boolean;
  testID?: string;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      accessibilityLabel={children}
      testID={testID}
      disabled={disabled}
      onPress={() => {
        tap();
        onPress();
      }}
      style={({ pressed }) => [
        {
          minHeight: 50,
          paddingHorizontal: 20,
          paddingVertical: 13,
          borderRadius: 12,
          backgroundColor: secondary ? c.soft : c.ink,
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          opacity: disabled ? 0.45 : pressed ? 0.75 : 1,
        },
        style,
      ]}
    >
      {icon && (
        <Icon name={icon} size={18} color={secondary ? c.ink : "#fff"} />
      )}
      <Text
        style={[s.label, { color: secondary ? c.ink : "#fff", fontSize: 15 }]}
      >
        {children}
      </Text>
    </Pressable>
  );
}
export function IconButton({
  name,
  label,
  onPress,
  active = false,
  style,
}: {
  name: IconName;
  label: string;
  onPress: () => void;
  active?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={() => {
        tap();
        onPress();
      }}
      style={({ pressed }) => [
        {
          width: 44,
          height: 44,
          borderRadius: 22,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: active
            ? c.blueSoft
            : pressed
              ? c.soft
              : "transparent",
        },
        style,
      ]}
    >
      <Icon name={name} color={active ? c.blue : c.ink} />
    </Pressable>
  );
}
export function Chip({
  label,
  selected,
  onPress,
}: {
  label: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      onPress={() => {
        tap();
        onPress();
      }}
      style={{
        minHeight: 44,
        paddingHorizontal: 16,
        paddingVertical: 11,
        borderRadius: 24,
        backgroundColor: selected ? c.ink : "transparent",
        justifyContent: "center",
      }}
    >
      <Text style={[s.label, { color: selected ? "#fff" : c.muted }]}>
        {label}
      </Text>
    </Pressable>
  );
}
export function Field({
  label,
  value,
  onChangeText,
  placeholder,
  multiline = false,
  keyboardType = "default",
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  placeholder?: string;
  multiline?: boolean;
  keyboardType?: React.ComponentProps<typeof TextInput>["keyboardType"];
}) {
  return (
    <View style={{ gap: 9, marginBottom: 22 }}>
      <Text style={s.label}>{label}</Text>
      <TextInput
        accessibilityLabel={label}
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={c.muted}
        multiline={multiline}
        keyboardType={keyboardType}
        returnKeyType={multiline ? "default" : "done"}
        onSubmitEditing={multiline ? undefined : Keyboard.dismiss}
        style={[
          s.input,
          multiline && { minHeight: 116, textAlignVertical: "top" },
        ]}
      />
    </View>
  );
}
export function Photo({
  uri,
  name = "",
  style,
  hidden = false,
}: {
  uri: string | null;
  name?: string;
  style?: StyleProp<ViewStyle>;
  hidden?: boolean;
}) {
  const [measuredWidth, setMeasuredWidth] = React.useState(80);
  const tones = ["#E1E7DF", "#E9E1DB", "#E3E5ED", "#E6E7D8"];
  const tone = tones[(name.charCodeAt(0) || 0) % tones.length];
  const source =
    uri === "demo:portrait"
      ? require("../../assets/editorial-portrait.png")
      : uri
        ? { uri }
        : undefined;
  return (
    <View
      onLayout={(event) => setMeasuredWidth(event.nativeEvent.layout.width)}
      style={[
        {
          backgroundColor: uri ? c.soft : tone,
          overflow: "hidden",
          alignItems: "center",
          justifyContent: "center",
        },
        style,
      ]}
    >
      {source && !hidden ? (
        <Image
          source={source}
          style={StyleSheet.absoluteFill}
          contentFit="cover"
          contentPosition="top center"
          transition={180}
          accessibilityLabel={`${name}的照片`}
        />
      ) : (
        <View style={{ alignItems: "center", justifyContent: "center" }}>
          {hidden ? <Icon name="eye-off" size={Math.min(26, measuredWidth * 0.4)} color="#758276" /> : <Text
            style={{
              fontSize: Math.min(72, measuredWidth * 0.4),
              fontWeight: "300",
              color: "#758276",
              fontFamily: font,
            }}
          >
            {name.slice(0, 1) || "+"}
          </Text>}
        </View>
      )}
    </View>
  );
}
export function Avatar({
  uri,
  name,
  size = 44,
  hidden = false,
}: {
  uri: string | null;
  name: string;
  size?: number;
  hidden?: boolean;
}) {
  return (
    <Photo
      uri={uri}
      name={name}
      hidden={hidden}
      style={{ width: size, height: size, borderRadius: size / 2 }}
    />
  );
}
export function SectionHeading({
  title,
  action,
  onPress,
}: {
  title: string;
  action?: string;
  onPress?: () => void;
}) {
  return (
    <View style={[s.between, { marginBottom: 17 }]}>
      <Text style={s.h2}>{title}</Text>
      {action && (
        <Pressable
          accessibilityRole="button"
          onPress={onPress}
          style={[s.row, { minHeight: 44, gap: 5 }]}
        >
          <Text style={[s.muted, { color: c.blue }]}>{action}</Text>
          <Icon name="arrow-up-right" size={15} color={c.blue} />
        </Pressable>
      )}
    </View>
  );
}
export function Empty({
  title,
  description,
  action,
  onPress,
  icon = "layers",
}: {
  title: string;
  description: string;
  action?: string;
  onPress?: () => void;
  icon?: IconName;
}) {
  return (
    <View
      style={{
        paddingVertical: 43,
        alignItems: "center",
        gap: 15,
        paddingHorizontal: 20,
      }}
    >
      <View style={{ width: 110, height: 112, marginBottom: 8 }}>
        <View style={{ position: "absolute", width: 73, height: 91, left: 25, top: 7, borderRadius: 7, backgroundColor: "#E4E9E0", transform: [{ rotate: "9deg" }] }} />
        <View style={{ position: "absolute", width: 73, height: 91, left: 11, top: 9, borderRadius: 7, backgroundColor: c.paper, borderWidth: 1, borderColor: c.line, padding: 15, transform: [{ rotate: "-6deg" }] }}><Icon name={icon} size={22} color="#72836C" /><View style={{ height: 2, backgroundColor: c.line, marginTop: 14, width: 33 }} /><View style={{ height: 2, backgroundColor: c.line, marginTop: 7, width: 21 }} /></View>
      </View>
      <Text style={[s.h2, { textAlign: "center" }]}>{title}</Text>
      <Text style={[s.muted, { textAlign: "center", maxWidth: 300 }]}>
        {description}
      </Text>
      {action && onPress && (
        <Button onPress={onPress} style={{ marginTop: 7 }}>
          {action}
        </Button>
      )}
    </View>
  );
}
export function Header({
  title,
  back = false,
  right,
  onBack,
}: {
  title?: string;
  back?: boolean;
  right?: React.ReactNode;
  onBack?: () => void;
}) {
  const hidden = useApp((a) => a.hidden),
    setHidden = useApp((a) => a.setHidden),
    demo = useApp((a) => a.data.demo);
  return (
    <View style={[s.between, { height: 52, marginBottom: 6 }]}>
      {back ? (
        <View style={[s.row, { gap: 5, flex: 1 }]}>
          <IconButton
            name="arrow-left"
            label="返回"
            onPress={onBack || (() =>
              router.canGoBack() ? router.back() : router.replace("/")
            )}
          />
          <Text style={[s.label, { fontSize: 17 }]}>{title}</Text>
        </View>
      ) : (
        <View style={[s.row, { gap: 10 }]}>
          <View
            style={{
              width: 23,
              height: 23,
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Icon name="aperture" color={c.ink} size={23} />
          </View>
          <Text
            style={{
              fontFamily: font,
              fontSize: 22,
              letterSpacing: -1,
              fontWeight: "700",
              color: c.ink,
            }}
          >
            astra
          </Text>
          {demo && <Text style={[s.tiny, { marginLeft: 5 }]}>示例</Text>}
        </View>
      )}
      {right || (
        <View style={s.row}>
          <IconButton
            name={hidden ? "eye-off" : "eye"}
            label={hidden ? "显示私人内容" : "隐藏私人内容"}
            onPress={() => setHidden(!hidden)}
          />
          <IconButton
            name="sliders"
            label="设置"
            onPress={() => router.push("/settings")}
          />
        </View>
      )}
    </View>
  );
}
export function Screen({
  children,
  back,
  title,
  right,
  scroll = true,
  footer,
  onBack,
}: {
  children: React.ReactNode;
  back?: boolean;
  title?: string;
  right?: React.ReactNode;
  scroll?: boolean;
  footer?: React.ReactNode;
  onBack?: () => void;
}) {
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const [keyboardVisible, setKeyboardVisible] = React.useState(false);
  const hasFooter = !!footer;
  React.useEffect(() => {
    if (!hasFooter) return;
    const show = Keyboard.addListener(Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow", () => setKeyboardVisible(true));
    const hide = Keyboard.addListener(Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide", () => setKeyboardVisible(false));
    return () => { show.remove(); hide.remove(); };
  }, [hasFooter]);
  const pad = width < 390 ? 20 : width > 900 ? 40 : 24;
  const content = (
    <View
      style={{
        width: "100%",
        maxWidth: 1040,
        alignSelf: "center",
        paddingHorizontal: pad,
      }}
    >
      {children}
      <View style={{ height: hasFooter ? 16 : 40 }} />
    </View>
  );
  return (
    <View style={{ flex: 1, backgroundColor: c.bg, paddingTop: insets.top }}>
      <View style={{ width: "100%", maxWidth: 1040, alignSelf: "center", paddingHorizontal: pad }}><Header back={back} title={title} right={right} onBack={onBack} /></View>
      {scroll ? (
        <ScrollView
          testID="screen-scroll"
          style={{ flex: 1 }}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode={Platform.OS === "ios" ? "interactive" : "on-drag"}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: hasFooter ? 0 : insets.bottom }}
        >
          {content}
        </ScrollView>
      ) : (
        content
      )}
      {hasFooter && <View style={{ borderTopWidth: StyleSheet.hairlineWidth, borderColor: c.line, backgroundColor: c.bg, paddingTop: 12, paddingBottom: keyboardVisible ? 12 : Math.max(insets.bottom, 14), paddingHorizontal: pad }}>
        <View style={{ width: "100%", maxWidth: 640, alignSelf: "center" }}>{footer}</View>
      </View>}
    </View>
  );
}
export function Name({
  value,
  style,
}: {
  value: string;
  style?: StyleProp<TextStyle>;
}) {
  const hidden = useApp((a) => a.hidden);
  return <Text style={[s.body, style]}>{hidden ? "已隐藏" : value}</Text>;
}
export function ErrorNote({ message }: { message: string }) {
  return message ? (
    <View
      accessibilityRole="alert"
      style={{
        padding: 14,
        borderRadius: 12,
        backgroundColor: "#FDEEF0",
        marginBottom: 16,
      }}
    >
      <Text style={[s.body, { color: c.red }]}>{message}</Text>
    </View>
  ) : null;
}

export function PageTitle({ title, subtitle, count, right }: {
  title: string; subtitle?: string; count?: number | string; right?: React.ReactNode;
}) {
  return <View style={[s.between, { alignItems: "flex-end", marginTop: 14, marginBottom: 25 }]}>
    <View style={{ flex: 1, paddingRight: 16 }}>
      <Text style={s.title}>{title}</Text>
      {subtitle && <Text style={[s.muted, { marginTop: 6 }]}>{subtitle}</Text>}
    </View>
    {count !== undefined && <Text style={{ fontFamily: font, fontSize: 48, lineHeight: 57, fontWeight: "200", letterSpacing: -2, color: "#8B928E", fontVariant: ["tabular-nums"] }}>{String(count).padStart(2, "0")}</Text>}
    {right}
  </View>;
}

export function Segments({ items, value, onChange }: {
  items: [string, string][]; value: string; onChange: (value: string) => void;
}) {
  return <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 25 }}>
    {items.map(([key, label]) => <Pressable key={key} accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ selected: value === key }} onPress={() => { tap(); onChange(key); }} style={{ minHeight: 46, justifyContent: "center", borderBottomWidth: 2, borderBottomColor: value === key ? c.ink : "transparent" }}>
      <Text style={[s.label, { fontSize: 14, color: value === key ? c.ink : c.muted }]}>{label}</Text>
    </Pressable>)}
  </ScrollView>;
}

export function FormSection({ number, title, caption, children }: {
  number: string; title: string; caption?: string; children: React.ReactNode;
}) {
  return <View style={{ marginBottom: 28 }}>
    <View style={[s.row, { gap: 10, marginBottom: 17 }]}>
      <Text style={[s.tiny, { color: c.blue, fontVariant: ["tabular-nums"] }]}>{number}</Text>
      <Text style={[s.label, { fontSize: 15 }]}>{title}</Text>
      <View style={{ flex: 1, height: 1, backgroundColor: c.line, marginLeft: 5 }} />
    </View>
    {caption && <Text style={[s.muted, { marginBottom: 16 }]}>{caption}</Text>}
    {children}
  </View>;
}

export function SearchField({ label, value, onChangeText, placeholder }: {
  label: string; value: string; onChangeText: (value: string) => void; placeholder: string;
}) {
  const hidden = useApp(a => a.hidden);
  return <View style={[s.row, { backgroundColor: "#ECEEEA", borderRadius: 10, paddingLeft: 15, gap: 10 }]}>
    <Icon name="search" size={17} color={c.muted} />
    <TextInput accessibilityLabel={label} value={hidden ? "" : value} editable={!hidden} onChangeText={onChangeText} placeholder={hidden ? "内容已隐藏" : placeholder} placeholderTextColor={c.muted} style={[s.body, { flex: 1, fontSize: 14, minHeight: 48, paddingVertical: 12 }]} />
    {!!value && <IconButton name="x" label={`清空${label}`} onPress={() => onChangeText("")} />}
  </View>;
}
