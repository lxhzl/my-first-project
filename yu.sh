# 注意 这不是占位符！！这个代码的作用是将模块里的东西全部塞系统里，然后挂上默认权限
SKIPUNZIP=0

VOLUME_KEY_DEVICE="/dev/input/event2"
your_module_id="murongltpo"

# 延迟输出函数
Outputs() {
  echo "$@"
  sleep 0.07
}

# 获取应用名称
get_app_name() {
  local package_name="$1"
  local app_name=$(dumpsys package "$package_name" | grep -i 'application-label:' | cut -d':' -f2 | tr -d '[:space:]')
  if [ -z "$app_name" ]; then
    app_name="$package_name"
  fi
  echo "$app_name"
}

# 监听音量键
Volume_key_monitoring() {
  local choose
  while :; do
    choose="$(getevent -qlc 1 | awk '{ print $3 }')"
    case "$choose" in
    KEY_VOLUMEUP) echo "0" && break ;;
    KEY_VOLUMEDOWN) echo "1" && break ;;
    esac
  done
}

# 安装APK
install_apk() {
  apk_file="$1"
  if [ -f "$apk_file" ]; then
    pm install -r "$apk_file"
    echo "软件安装成功."
  else
    echo "Error: $apk_file 未找到!"
    exit 1
  fi
}

# 安装Magisk模块
install_module() {
  local zipfile="$1"
  unzip -o "$zipfile" -d "/data/adb/modules_update"
  return 0
}

# 检测冲突的Magisk模块
check_conflict_modules() {
  local conflict_module_detected=false
  for module_dir in /data/adb/modules/*; do
    if [ -d "$module_dir" ]; then
      current_module_id=$(grep -m 1 'id=' "$module_dir/module.prop" | cut -d '=' -f2)
      
      # 排除自身模块
      if [ "$current_module_id" == "$your_module_id" ]; then
        continue
      fi

      prop_file="$module_dir/system.prop"
      if [ -f "$prop_file" ] && grep -q 'persist.oplus.display.vrr' 'persist.oplus.display.vrr.adfr' 'persist.oplus.display.pixelworks' "$prop_file"; then
        conflict_module_detected=true
        module_prop="$module_dir/module.prop"
        if [ -f "$module_prop" ]; then
          conflict_module_name=$(grep -m 1 'name=' "$module_prop" | cut -d '=' -f2)
          
          Outputs "检测到冲突的Magisk模块: $conflict_module_name"
          Outputs "请问是否卸载？"
          Outputs "   - 音量上键 = 卸载模块"
          Outputs "   - 音量下键 = 取消安装"

          branch=$(Volume_key_monitoring)

          if [ "$branch" == "0" ]; then
            Outputs "正在卸载冲突模块..."
            if [ -f "$module_dir/service.sh" ]; then
              "$module_dir/service.sh" --stop
            fi
            rm -rf "$module_dir"
            if [ $? -eq 0 ]; then
              Outputs "卸载成功。"
            else
              Outputs "卸载失败，请检查权限或手动卸载。"
              exit 1
            fi
          else
            Outputs "取消安装。"
            exit 1
          fi
        fi
      fi
    fi
  done

  if [ "$conflict_module_detected" = false ]; then
    Outputs "没有检测到冲突的Magisk模块。"
  fi
}

check_conflict_modules