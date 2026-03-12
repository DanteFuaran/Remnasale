#!/bin/bash

# Переменные для отслеживания состояния установки
INSTALL_STARTED=false
INSTALL_COMPLETED=false
SOURCE_DIR=""
CLEANUP_DIRS=()
TEMP_REPO=""
SCRIPT_CWD="$(cd "$(dirname "$0")" && pwd)"
CLONE_DIR=""

# Переменные путей
PROJECT_DIR="/opt/remnasale"
ENV_FILE="$PROJECT_DIR/.env"
REPO_DIR="/opt/remnasale"
REMNAWAVE_DIR="/opt/remnawave"
SYSTEM_INSTALL_DIR="/usr/local/lib/remnasale"

# Ветка, версия и репозиторий — единый источник: $PROJECT_DIR/version
# Формат файла:
#   version: x.x.x
#   branch:  main
#   repo:    https://github.com/...
REPO_URL="https://github.com/DanteFuaran/Remnasale.git"
REPO_BRANCH="main"
for _uf in "$PROJECT_DIR/version" "$SCRIPT_CWD/version" "$SCRIPT_CWD/.update"; do
    if [ -f "$_uf" ]; then
        _br=$(grep '^branch:' "$_uf" | cut -d: -f2 | tr -d ' \n')
        _ru=$(grep '^repo:'   "$_uf" | cut -d: -f2- | tr -d ' \n')
        [ -n "$_br" ] && REPO_BRANCH="$_br"
        [ -n "$_ru" ] && REPO_URL="$_ru"
        break
    fi
done

# Статус обновлений
UPDATE_AVAILABLE=0
AVAILABLE_VERSION="unknown"
CHECK_UPDATE_PID=""
UPDATE_STATUS_FILE=""

# ═══════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ ТЕРМИНАЛА И ОБРАБОТКА ПРЕРЫВАНИЙ
# ═══════════════════════════════════════════════
cleanup_terminal() {
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

handle_interrupt() {
    cleanup_terminal
    echo
    echo -e "${RED}⚠️  Скрипт был остановлен пользователем${NC}"
    echo
    exit 130
}

trap cleanup_terminal EXIT
trap handle_interrupt INT TERM

# ═══════════════════════════════════════════════
# ЦВЕТА
# ═══════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
DARKGRAY='\033[1;30m'

# ═══════════════════════════════════════════════
# УТИЛИТЫ ВЫВОДА
# ═══════════════════════════════════════════════

# ═══════════════════════════════════════════════
# СПИННЕРЫ
# ═══════════════════════════════════════════════
show_spinner() {
  local pid=$!
  local delay=0.08
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0 msg="$1"
  tput civis 2>/dev/null || true
  while kill -0 $pid 2>/dev/null; do
    printf "\r${GREEN}%s${NC}  %s" "${spin[$i]}" "$msg"
    i=$(( (i+1) % 10 ))
    sleep $delay
  done
  wait $pid 2>/dev/null
  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    printf "\r${GREEN}✅${NC} %s\n" "$msg"
  else
    printf "\r${RED}✖${NC}  %s\n" "$msg"
  fi
  tput cnorm 2>/dev/null || true
  return $exit_code
}

show_spinner_timer() {
  local seconds=$1
  local msg="$2"
  local done_msg="${3:-$msg}"
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  local delay=0.08
  local elapsed=0
  tput civis 2>/dev/null || true
  while [ $elapsed -lt $seconds ]; do
    local remaining=$((seconds - elapsed))
    for ((j=0; j<12; j++)); do
      printf "\r\033[K${GREEN}%s${NC}  %s (%d сек)" "${spin[$i]}" "$msg" "$remaining"
      sleep $delay
      i=$(( (i+1) % 10 ))
    done
    ((elapsed++)) || true
  done
  printf "\r\033[K${GREEN}✅${NC} %s\n" "$done_msg"
  tput cnorm 2>/dev/null || true
}

# Спинер с ожиданием строки в логах
show_spinner_until_log() {
  local container="$1"
  local pattern="$2"
  local msg="$3"
  local timeout=${4:-90}
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  local elapsed=0
  local delay=0.08
  local check_interval=1
  local loops_per_check=$((check_interval * 12))  # 12 loops per second at 0.08s delay
  local loop_count=0
  
  tput civis 2>/dev/null || true
  
  while [ $elapsed -lt $timeout ]; do
    # Анимация спинера
    printf "\r${GREEN}%s${NC}  %s ${DARKGRAY}(%d/%d сек)${NC}" "${spin[$i]}" "$msg" "$elapsed" "$timeout"
    i=$(( (i+1) % 10 ))
    sleep $delay
    loop_count=$((loop_count + 1))
    
    # Проверяем логи каждую секунду
    if [ $((loop_count % loops_per_check)) -eq 0 ]; then
      elapsed=$((elapsed + 1))
      local logs=$(docker logs "$container" 2>&1 | tail -100)
      
      # Проверяем паттерн успеха
      if echo "$logs" | grep -q "$pattern"; then
        printf "\r${GREEN}✅${NC} %s\n" "$msg"
        tput cnorm 2>/dev/null || true
        return 0
      fi
      
      # Проверяем ошибки
      if echo "$logs" | grep -E "^\s*(ERROR|CRITICAL|Traceback)" >/dev/null 2>&1; then
        printf "\r${YELLOW}🔍${NC} %s (проверка)\n" "$msg"
        tput cnorm 2>/dev/null || true
        return 2
      fi
    fi
  done
  
  printf "\r\033[K"
  tput cnorm 2>/dev/null || true
  return 1
}

# Спинер без сообщения (просто ждём процесс)
show_spinner_silent() {
  local pid=$!
  local delay=0.08
  local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 10 ))
    sleep $delay
  done
  wait $pid 2>/dev/null || true
}

# Красивый вывод
print_action()  { :; }
print_error()   { printf "${RED}✖ %b${NC}\n" "$1"; }
print_success() { printf "${GREEN}✅${NC} %b\n" "$1"; }

# ═══════════════════════════════════════════════
# МЕНЮ СО СТРЕЛОЧКАМИ
# ═══════════════════════════════════════════════
show_arrow_menu() {
    local title="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0
    local _esc_label="${MENU_ESC_LABEL:-Назад}"

    # Сохраняем настройки терминала
    local original_stty
    original_stty=$(stty -g 2>/dev/null)

    # Скрываем курсор
    tput civis 2>/dev/null || true

    # Отключаем canonical mode и echo
    stty -icanon -echo min 1 time 0 2>/dev/null || true

    # Пропускаем разделители при начальной позиции
    while [[ "${options[$selected]}" =~ ^[─━═[:space:]]*$ ]]; do
        ((selected++))
        if [ $selected -ge $num_options ]; then
            selected=0
            break
        fi
    done

    while true; do
        clear
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${GREEN}   $title${NC}"
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo

        for i in "${!options[@]}"; do
            # Проверяем, является ли элемент разделителем
            if [[ "${options[$i]}" =~ ^[─━═[:space:]]*$ ]]; then
                echo -e "${DARKGRAY}${options[$i]}${NC}"
            elif [ $i -eq $selected ]; then
                echo -e "${BLUE}▶${NC} ${YELLOW}${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done

        echo
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${DARKGRAY}${BLUE}↑↓${DARKGRAY}: Навигация  ${BLUE}Enter${DARKGRAY}: Выбор  ${BLUE}Esc${DARKGRAY}: ${_esc_label}${NC}"

        local key
        read -rsn1 key 2>/dev/null || key=""

        if [[ "$key" == $'\e' ]]; then
            local seq1="" seq2=""
            read -rsn1 -t 0.1 seq1 2>/dev/null || seq1=""
            if [[ "$seq1" == '[' ]]; then
                read -rsn1 -t 0.1 seq2 2>/dev/null || seq2=""
                case "$seq2" in
                    'A')  # Стрелка вверх
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        while [[ "${options[$selected]}" =~ ^[─━═[:space:]]*$ ]]; do
                            ((selected--))
                            if [ $selected -lt 0 ]; then
                                selected=$((num_options - 1))
                            fi
                        done
                        ;;
                    'B')  # Стрелка вниз
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        while [[ "${options[$selected]}" =~ ^[─━═[:space:]]*$ ]]; do
                            ((selected++))
                            if [ $selected -ge $num_options ]; then
                                selected=0
                            fi
                        done
                        ;;
                esac
            else
                # Чистый Esc без последовательности - назад
                stty "$original_stty" 2>/dev/null || true
                tput cnorm 2>/dev/null || true
                return 255
            fi
        else
            local key_code
            if [ -n "$key" ]; then
                key_code=$(printf '%d' "'$key" 2>/dev/null || echo 0)
            else
                key_code=13
            fi

            if [ "$key_code" -eq 10 ] || [ "$key_code" -eq 13 ]; then
                stty "$original_stty" 2>/dev/null || true
                tput cnorm 2>/dev/null || true
                return $selected
            fi
        fi
    done
}

# ═══════════════════════════════════════════════
# ВВОД ТЕКСТА
# ═══════════════════════════════════════════════
reading() {
    local prompt="$1"
    local var_name="$2"
    local input
    echo
    local ps=$'\001\033[34m\002➜\001\033[0m\002  \001\033[33m\002'"$prompt"$'\001\033[0m\002 '
    read -e -p "$ps" input
    eval "$var_name='$input'"
}

reading_inline() {
    local prompt="$1"
    local var_name="$2"
    local input
    local ps=$'\001\033[34m\002➜\001\033[0m\002  \001\033[33m\002'"$prompt"$'\001\033[0m\002 '
    read -e -p "$ps" input
    eval "$var_name='$input'"
}

confirm_action() {
    echo -e "${YELLOW}⚠️  Нажмите Enter для подтверждения, или Esc для отмены.${NC}"

    local key
    while true; do
        read -s -n 1 key
        if [[ "$key" == $'\x1b' ]]; then
            return 1
        elif [[ "$key" == "" ]]; then
            break
        fi
    done

    echo
    echo -e "${RED}⚠️  Вы уверены? Это действие нельзя отменить.${NC}"
    echo
    echo -e "${YELLOW}⚠️  Нажмите Enter для подтверждения, или Esc для отмены.${NC}"

    while true; do
        read -s -n 1 key
        if [[ "$key" == $'\x1b' ]]; then
            return 1
        elif [[ "$key" == "" ]]; then
            return 0
        fi
    done
}

# ═══════════════════════════════════════════════
# ПРОВЕРКА ДОМЕНА
# ═══════════════════════════════════════════════
get_server_ip() {
    local ip=""

    ip=$(curl -s4 --max-time 5 ifconfig.me 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    ip=$(curl -s4 --max-time 5 icanhazip.com 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    ip=$(curl -s4 --max-time 5 ident.me 2>/dev/null)
    if [ -n "$ip" ] && [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$ip" ] && [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    echo "unknown"
}

check_domain() {
    local domain="$1"

    local domain_ip
    domain_ip=$(dig +short "$domain" A 2>/dev/null | head -1)

    local server_ip
    server_ip=$(get_server_ip)

    if [ -z "$domain_ip" ]; then
        echo
        echo -e "${RED}✖ Домен ${YELLOW}$domain${RED} не привязан к IP вашего сервера ${YELLOW}$server_ip${NC}"
        echo -e "${RED}❗Убедитесь что DNS записи настроены правильно.${NC}"
        return 1
    fi

    local ip_match=false

    # Проверяем прямое совпадение с внешним IP
    if [ "$domain_ip" = "$server_ip" ]; then
        ip_match=true
    else
        # Проверяем локальные IP интерфейсов (для Docker/NAT)
        local local_ips
        local_ips=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')

        if [ -n "$local_ips" ]; then
            while IFS= read -r local_ip; do
                if [ "$domain_ip" = "$local_ip" ]; then
                    ip_match=true
                    break
                fi
            done <<< "$local_ips"
        fi
    fi

    if [ "$ip_match" = false ]; then
        echo
        echo -e "${RED}✖ Домен ${YELLOW}$domain${RED} не привязан к IP вашего сервера ${YELLOW}$server_ip${NC}"
        echo -e "${RED}⚠️  Убедитесь что DNS записи настроены правильно.${NC}"
        return 1
    fi

    return 0
}

# Функция для безопасного обновления переменной в .env файле
update_env_var() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"
    
    # Экранируем спецсимволы для sed
    local escaped_value=$(printf '%s\n' "$var_value" | sed -e 's/[\/&]/\\&/g')
    
    # Проверяем, существует ли переменная в файле
    if grep -q "^${var_name}=" "$env_file"; then
        # Заменяем существующее значение
        sed -i "s|^${var_name}=.*|${var_name}=${escaped_value}|" "$env_file"
    else
        # Добавляем новую переменную
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Функция для проверки установлен ли бот
is_installed() {
    # Бот считается установленным только если:
    # 1. Директория существует
    # 2. Есть критические файлы (docker-compose.yml и .env)
    # 3. Docker контейнеры запущены или есть следы работы
    if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ] && [ -f "$PROJECT_DIR/.env" ]; then
        return 0  # installed
    fi
    return 1  # not installed
}

# Функция для сохранения критических переменных из .env перед обновлением
preserve_env_vars() {
    local env_file="$1"
    local temp_storage="/tmp/env_backup_$$"
    
    # Сохраняем ВСЕ переменные окружения из .env файла
    # Исключаем только комментарии и пустые строки
    if [ -f "$env_file" ]; then
        grep -v "^#" "$env_file" | grep -v "^$" > "$temp_storage" 2>/dev/null || true
    fi
    echo "$temp_storage"
}

# Функция для восстановления переменных в .env после обновления
restore_env_vars() {
    local env_file="$1"
    local temp_storage="$2"
    
    # Переменные которые НЕ следует перезаписывать (пароли, криптографические ключи)
    # Переменные которые БУДУТ восстановлены: APP_DOMAIN, BOT_TOKEN, BOT_DEV_ID, и другие пользовательские данные
    local protected_vars=(
        "APP_CRYPT_KEY"
        "DB_PASSWORD"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "SECRET_KEY"
        "JWT_SECRET"
        "API_KEY"
    )
    
    if [ -f "$temp_storage" ]; then
        # Читаем сохранённые переменные и обновляем их в .env
        while IFS='=' read -r var_name var_value; do
            if [ -n "$var_name" ] && [ -n "$var_value" ]; then
                # Пропускаем пустые строки
                var_name=$(echo "$var_name" | xargs)
                if [ -n "$var_name" ]; then
                    # Проверяем не входит ли переменная в защищённый список
                    is_protected=0
                    for protected in "${protected_vars[@]}"; do
                        if [ "$var_name" = "$protected" ]; then
                            is_protected=1
                            break
                        fi
                    done
                    
                    # Обновляем только незащищённые переменные (включая домен, токен и ID)
                    if [ $is_protected -eq 0 ]; then
                        update_env_var "$env_file" "$var_name" "$var_value"
                    fi
                fi
            fi
        done < "$temp_storage"
        
        # Удаляем временный файл
        rm -f "$temp_storage" 2>/dev/null || true
    fi
}

# Функция для получения версии из файла version
get_version_from_file() {
    local update_file="$1"
    if [ -f "$update_file" ]; then
        grep '^version:' "$update_file" 2>/dev/null | cut -d: -f2 | tr -d ' \n' || echo ""
    else
        echo ""
    fi
}

# Функция для получения локальной версии (из version)
get_local_version() {
    # Приоритет: сначала production ($PROJECT_DIR), затем текущая папка ($SCRIPT_CWD)
    # Это гарантирует, что при установленном боте будет браться версия из production,
    # а не из временной клонированной папки (при запуске через install-wrapper.sh)
    for _uf in "$PROJECT_DIR/version" "$SCRIPT_CWD/version"; do
        if [ -f "$_uf" ]; then
            # Поддерживаем оба формата: "version: X.Y.Z" и plain "X.Y.Z"
            local _v=$(grep '^version:' "$_uf" 2>/dev/null | cut -d: -f2 | tr -d ' \n')
            if [ -n "$_v" ]; then
                echo "$_v"
                return
            else
                # Plain format — первая непустая строка которая выглядит как версия (x.y.z)
                _v=$(grep -v '^#\|^[[:space:]]*$' "$_uf" 2>/dev/null | head -1 | tr -d ' \n')
                if [ -n "$_v" ]; then
                    echo "$_v"
                    return
                fi
            fi
        fi
    done
    echo ""
}

# Функция для парсинга версии из содержимого файла version
# Поддерживает оба формата: "version: X.Y.Z" и plain "X.Y.Z"
parse_version_from_content() {
    local content="$1"
    local _v=$(echo "$content" | grep '^version:' 2>/dev/null | cut -d: -f2 | tr -d ' \n')
    if [ -n "$_v" ]; then
        echo "$_v"
    else
        # Plain format — первая непустая строка
        echo "$content" | grep -v '^#\|^[[:space:]]*$' 2>/dev/null | head -1 | tr -d ' \n'
    fi
}

# Функция для сравнения версий (true если version1 < version2)
version_less_than() {
    local v1="$1"
    local v2="$2"
    
    # Простое сравнение версий (для формата X.Y.Z)
    # Преобразуем версии в числа для сравнения
    local v1_num=$(echo "$v1" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    local v2_num=$(echo "$v2" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    
    [ "$v1_num" -lt "$v2_num" ]
}

# Функция для проверки доступности обновлений
check_updates_available() {
    # Создаем временный файл для хранения статуса и версии
    UPDATE_STATUS_FILE=$(mktemp)
    echo "0" > "$UPDATE_STATUS_FILE"
    
    # Проверка обновлений в фоне
    {
        # Получаем локальную версию из PROJECT_DIR (production)
        LOCAL_VERSION=$(get_local_version)
        
        # Создаём временную папку для проверки версии
        TEMP_CHECK_DIR=$(mktemp -d)
        
        # Клонируем только последний коммит нужной ветки (быстро, ~500kb)
        if git clone -b "$REPO_BRANCH" --depth 1 --single-branch "$REPO_URL" "$TEMP_CHECK_DIR" >/dev/null 2>&1; then
            # Получаем удаленную версию из клонированного репозитория (файл version)
            if [ -f "$TEMP_CHECK_DIR/version" ]; then
                REMOTE_VERSION=$(parse_version_from_content "$(cat "$TEMP_CHECK_DIR/version")")
            fi
            
            # Удаляем временную папку
            rm -rf "$TEMP_CHECK_DIR" 2>/dev/null || true
            
            # Сравниваем версии (inline без вызова функции, т.к. подоболочка не наследует функции)
            if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ]; then
                # Преобразуем версии в числа для сравнения
                local_num=$(echo "$LOCAL_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
                remote_num=$(echo "$REMOTE_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
                
                # Показываем обновление только если локальная версия НИЖЕ удаленной
                if [ "$local_num" -lt "$remote_num" ]; then
                    echo "1|$REMOTE_VERSION" > "$UPDATE_STATUS_FILE"
                else
                    echo "0|$REMOTE_VERSION" > "$UPDATE_STATUS_FILE"
                fi
            else
                echo "0|unknown" > "$UPDATE_STATUS_FILE"
            fi
        else
            # Если не удалось клонировать, пробуем старый способ через raw URL
            rm -rf "$TEMP_CHECK_DIR" 2>/dev/null || true
            
            GITHUB_RAW_URL=$(echo "$REPO_URL" | sed 's|github.com|raw.githubusercontent.com|; s|\.git$||')
            REMOTE_VERSION_URL="${GITHUB_RAW_URL}/${REPO_BRANCH}/version"
            REMOTE_CONTENT=$(curl -s "$REMOTE_VERSION_URL" 2>/dev/null)
            REMOTE_VERSION=$(parse_version_from_content "$REMOTE_CONTENT")
            
            if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ]; then
                # Преобразуем версии в числа для сравнения (inline без вызова функции)
                local_num=$(echo "$LOCAL_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
                remote_num=$(echo "$REMOTE_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
                
                # Показываем обновление только если локальная версия НИЖЕ удаленной
                if [ "$local_num" -lt "$remote_num" ]; then
                    echo "1|$REMOTE_VERSION" > "$UPDATE_STATUS_FILE"
                else
                    echo "0|$REMOTE_VERSION" > "$UPDATE_STATUS_FILE"
                fi
            else
                echo "0|unknown" > "$UPDATE_STATUS_FILE"
            fi
        fi
        
        # Очистка временной директории после проверки
        rm -rf "$TEMP_CHECK_DIR" 2>/dev/null || true
    } &
    CHECK_UPDATE_PID=$!
}

wait_for_update_check() {
    if [ -n "$CHECK_UPDATE_PID" ]; then
        wait $CHECK_UPDATE_PID 2>/dev/null || true
    fi
    
    # Читаем результат из файла (формат: status|version)
    if [ -n "$UPDATE_STATUS_FILE" ] && [ -f "$UPDATE_STATUS_FILE" ]; then
        local update_info=$(cat "$UPDATE_STATUS_FILE" 2>/dev/null || echo "0|unknown")
        UPDATE_AVAILABLE=$(echo "$update_info" | cut -d'|' -f1)
        AVAILABLE_VERSION=$(echo "$update_info" | cut -d'|' -f2)
        rm -f "$UPDATE_STATUS_FILE" 2>/dev/null || true
    fi
}

# Функция для проверки режима (установка или меню)
check_mode() {
    # Если передан аргумент --install, пропускаем меню
    if [ "$1" = "--install" ]; then
        return 0
    fi
    
    # Проверяем обновления в фоне перед показом меню
    check_updates_available
    
    # Если бот установлен и скрипт вызван без аргументов, показываем полное меню
    if is_installed && [ -z "$1" ]; then
        show_full_menu
    fi
    
    # Если бот не установлен и скрипт вызван без аргументов, показываем меню с одним пунктом
    if ! is_installed && [ -z "$1" ]; then
        show_simple_menu
    fi
}

# Функция очистки при выходе из установки
cleanup_on_exit() {
    # Удаляем скачанные файлы если они были скачаны но установка не началась
    if [ -n "$TEMP_REPO" ] && [ -d "$TEMP_REPO" ]; then
        rm -rf "$TEMP_REPO" 2>/dev/null || true
    fi
    # Удаляем временную папку клонирования репозитория
    if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
        cd /opt 2>/dev/null || true
        rm -rf "$CLONE_DIR" 2>/dev/null || true
    fi
}

# Перезапуск через системный скрипт с предварительной очисткой CLONE_DIR
# Используется вместо exec "$0" чтобы не оставлять /tmp/tmp.* папку
restart_script() {
    local extra_arg="${1:-}"
    # Явно удаляем CLONE_DIR перед exec (trap EXIT не сработает после exec)
    if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
        local _clone_to_remove="$CLONE_DIR"
        CLONE_DIR=""
        cd /opt 2>/dev/null || true
        rm -rf "$_clone_to_remove" 2>/dev/null || true
    fi

    # Для установки (--install) нужно клонировать репозиторий,
    # т.к. системная копия содержит только remnasale-install.sh без исходников
    if [ "$extra_arg" = "--install" ]; then
        CLONE_DIR=$(mktemp -d)
        if git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1; then
            chmod +x "$CLONE_DIR/remnasale-install.sh"
            cd "$CLONE_DIR"
            exec "$CLONE_DIR/remnasale-install.sh" --install "$CLONE_DIR" "${INSTALL_MODE:-dev}"
        else
            echo -e "${RED}❌ Ошибка при клонировании репозитория${NC}"
            rm -rf "$CLONE_DIR" 2>/dev/null || true
            exit 1
        fi
    fi

    # Для остальных случаев — запускаем из системной папки если доступна, иначе $0
    local _target="/usr/local/lib/remnasale/remnasale-install.sh"
    if [ ! -f "$_target" ]; then
        _target="$0"
    fi
    if [ -n "$extra_arg" ]; then
        exec "$_target" "$extra_arg"
    else
        exec "$_target"
    fi
}

# Простое меню при отсутствии бота
show_simple_menu() {
    # Ждём завершения проверки обновлений
    wait_for_update_check
    
    # Определяем версию для отображения
    local display_version=""
    if [ -f "$SCRIPT_CWD/version" ]; then
        display_version=$(grep '^version:' "$SCRIPT_CWD/version" 2>/dev/null | cut -d: -f2 | tr -d ' \n' || echo "")
    elif [ -n "$AVAILABLE_VERSION" ] && [ "$AVAILABLE_VERSION" != "unknown" ]; then
        display_version="$AVAILABLE_VERSION"
    fi
    
    # Формируем заголовок
    local menu_title
    if [ -n "$display_version" ]; then
        menu_title="       🚀 Remnasale v${display_version}\n${DARKGRAY}Проект развивается благодаря вашей поддержке\n        https://github.com/DanteFuaran${NC}"
    else
        menu_title="       🚀 Remnasale\n${DARKGRAY}Проект развивается благодаря вашей поддержке\n        https://github.com/DanteFuaran${NC}"
    fi
    MENU_ESC_LABEL="Выход"
    
    show_arrow_menu "$menu_title" \
        "🚀  Установить" \
        "──────────────────────────────────────" \
        "❌  Выход"
    local choice=$?
    
    case $choice in
        0)  # Установить
            restart_script --install
            ;;
        2|255)  # Выход / Esc
            clear
            exit 0
            ;;
    esac
}

# Полное меню при установленном боте
show_full_menu() {
    # Получаем текущую версию
    local LOCAL_VERSION=$(get_local_version)
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0.1.0"
    
    # Ждём завершения проверки обновлений
    wait_for_update_check
    
    # Создаём глобальную команду remnasale если её нет
    if [ ! -f "/usr/local/bin/remnasale" ]; then
        (  
            sudo tee /usr/local/bin/remnasale > /dev/null << 'EOF'
#!/bin/bash
# Запускаем remnasale-install.sh из системной папки
if [ -f "/usr/local/lib/remnasale/remnasale-install.sh" ]; then
    exec /usr/local/lib/remnasale/remnasale-install.sh
else
    echo "❌ remnasale-install.sh не найден. Переустановите бота."
    exit 1
fi
EOF
            sudo chmod +x /usr/local/bin/remnasale
            sudo ln -sf /usr/local/bin/remnasale /usr/local/bin/rs
        ) >/dev/null 2>&1
    fi
    
    # Формируем пункт обновления с индикатором
    local update_label="🔄  Обновить"
    if [ $UPDATE_AVAILABLE -eq 1 ]; then
        if [ -n "$AVAILABLE_VERSION" ] && [ "$AVAILABLE_VERSION" != "unknown" ]; then
            update_label="🔄  Обновить ${YELLOW}( Доступно обновление - версия $AVAILABLE_VERSION ! )${NC}"
        else
            update_label="🔄  Обновить ${YELLOW}( Доступно обновление! )${NC}"
        fi
    fi
    
    while true; do
        local menu_title="       🚀 Remnasale v${LOCAL_VERSION}\n${DARKGRAY}Проект развивается благодаря вашей поддержке\n        https://github.com/DanteFuaran${NC}"
        MENU_ESC_LABEL="Выход"
        show_arrow_menu "$menu_title" \
            "$update_label" \
            "ℹ️   Просмотр логов" \
            "📊  Логи в реальном времени" \
            "──────────────────────────────────────" \
            "🔃  Перезагрузить бота" \
            "🔃  Перезагрузить с логами" \
            "⬆️   Включить бота" \
            "⬇️   Выключить бота" \
            "──────────────────────────────────────" \
            "�  Автобекап" \
            "──────────────────────────────────────" \
            "🔄  Переустановить" \
            "⚙️   Изменить настройки" \
            "🧹  Очистить данные" \
            "🗑️   Удалить бота" \
            "──────────────────────────────────────" \
            "❌  Выход"
        local choice=$?
        
        case $choice in
            0)  manage_update_bot ;;
            1)  manage_view_logs ;;
            2)  manage_view_logs_live ;;
            4)  manage_restart_bot ;;
            5)  manage_restart_bot_with_logs ;;
            6)  manage_start_bot ;;
            7)  manage_stop_bot ;;
            9)  manage_autobackup ;;
            11) manage_reinstall_bot ;;
            12) manage_change_settings ;;
            13) manage_cleanup_database ;;
            14) manage_uninstall_bot ;;
            16) clear; exit 0 ;;
            255) clear; exit 0 ;;
        esac
    done
}

# ═══════════════════════════════════════════════
# АВТОБЕКАП
# ═══════════════════════════════════════════════

AUTOBACKUP_SCRIPT="/usr/local/lib/remnasale/autobackup.sh"
AUTOBACKUP_CONFIG="/opt/remnasale/.autobackup"

# Отправка файла в Telegram
_send_backup_to_telegram() {
    local token="$1"
    local chat_id="$2"
    local file_path="$3"
    local caption="${4:-}"
    curl -s -F "chat_id=$chat_id" \
         -F "document=@$file_path" \
         -F "caption=$caption" \
         "https://api.telegram.org/bot${token}/sendDocument" >/dev/null 2>&1
}

# Создание скрипта автобекапа
_create_autobackup_script() {
    local bot_token="$1"
    local chat_id="$2"
    sudo mkdir -p "$(dirname "$AUTOBACKUP_SCRIPT")" 2>/dev/null || true
    cat > "$AUTOBACKUP_SCRIPT" << 'BACKUP_SCRIPT'
#!/bin/bash
# Remnasale Auto-Backup Script
set -euo pipefail

CONFIG="/opt/remnasale/.autobackup"
[ -f "$CONFIG" ] || exit 0
BOT_TOKEN=$(grep '^bot_token:' "$CONFIG" | cut -d: -f2- | tr -d ' ')
CHAT_ID=$(grep '^chat_id:' "$CONFIG" | cut -d: -f2- | tr -d ' ')
[ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && exit 1

BACKUP_DIR="/opt/remnasale/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
DUMP_FILE="${BACKUP_DIR}/dump_${TIMESTAMP}.sql.gz"
DIR_ARCHIVE="${BACKUP_DIR}/dir_${TIMESTAMP}.tar.gz"
FINAL_FILE="${BACKUP_DIR}/Remnasale_${TIMESTAMP}.tar.gz"

# Дамп БД
docker exec remnasale-db pg_dumpall -c -U postgres 2>/dev/null | gzip -9 > "$DUMP_FILE"
if [ ! -s "$DUMP_FILE" ]; then
    rm -f "$DUMP_FILE"
    exit 1
fi

# Архив директории
tar -czf "$DIR_ARCHIVE" --exclude='*.log' --exclude='*.tmp' --exclude='.git' --exclude='backups' -C /opt remnasale 2>/dev/null || true

# Финальный архив
tar -czf "$FINAL_FILE" -C "$BACKUP_DIR" "$(basename "$DUMP_FILE")" "$(basename "$DIR_ARCHIVE")" 2>/dev/null
rm -f "$DUMP_FILE" "$DIR_ARCHIVE"

if [ -s "$FINAL_FILE" ]; then
    SIZE=$(du -h "$FINAL_FILE" | awk '{print $1}')
    DATE=$(date '+%d.%m.%Y %H:%M')
    CAPTION="💾 #remnasale_backup
➖➖➖➖➖➖➖➖➖
✅ Бекап успешно создан
📁 БД + Директория
📏 Размер: ${SIZE}
📅 ${DATE} MSK"
    curl -s -F "chat_id=$CHAT_ID" \
         -F "document=@$FINAL_FILE" \
         -F "caption=$CAPTION" \
         "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" >/dev/null 2>&1
    find "$BACKUP_DIR" -name "Remnasale_*.tar.gz" -mtime +7 -delete 2>/dev/null || true
fi
BACKUP_SCRIPT
    chmod +x "$AUTOBACKUP_SCRIPT"
}

# Получение cron-выражения по частоте
_get_cron_schedule() {
    local freq="$1"
    case "$freq" in
        hourly)  echo "0 * * * *" ;;
        daily)   echo "0 21 * * *" ;;   # 00:00 MSK = 21:00 UTC
        weekly)  echo "0 21 * * 0" ;;   # воскресенье 00:00 MSK
        monthly) echo "0 21 1 * *" ;;   # 1-е число 00:00 MSK
    esac
}

# Проверка статуса автобекапа
_autobackup_is_active() {
    crontab -l 2>/dev/null | grep -q "$AUTOBACKUP_SCRIPT"
}

# Получение текущей частоты
_autobackup_get_frequency() {
    if ! _autobackup_is_active; then
        echo ""
        return
    fi
    local cron_line
    cron_line=$(crontab -l 2>/dev/null | grep "$AUTOBACKUP_SCRIPT")
    case "$cron_line" in
        "0 * * * *"*)    echo "Каждый час" ;;
        "0 21 * * *"*)   echo "Каждый день (00:00 МСК)" ;;
        "0 21 * * 0"*)   echo "Каждую неделю (Вс 00:00 МСК)" ;;
        "0 21 1 * *"*)   echo "Каждый месяц (1-е число, 00:00 МСК)" ;;
        *)               echo "Пользовательское расписание" ;;
    esac
}

manage_autobackup() {
    while true; do
        local status_label
        if _autobackup_is_active; then
            local freq
            freq=$(_autobackup_get_frequency)
            status_label="📊 Статус: ${GREEN}Активен${NC} (${freq})"
        else
            status_label="📊 Статус: ${RED}Не настроен${NC}"
        fi

        clear
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${GREEN}       💾 АВТОБЕКАП REMNASALE${NC}"
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo
        echo -e "  $status_label"
        echo

        local menu_items=()
        if _autobackup_is_active; then
            menu_items+=("⚙️   Изменить настройки")
            menu_items+=("📤  Создать бекап сейчас")
            menu_items+=("⛔  Остановить автобекап")
        else
            menu_items+=("⚙️   Настройка автобекапа")
        fi
        menu_items+=("──────────────────────────────────────")
        menu_items+=("❌  Назад")

        show_arrow_menu "💾 АВТОБЕКАП" "${menu_items[@]}"
        local choice=$?

        case $choice in
            0)
                # Настройка / Изменить
                clear
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${GREEN}   ⚙️  НАСТРОЙКА АВТОБЕКАПА${NC}"
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo

                # Токен бота
                local backup_bot_token=""
                if [ -f "$AUTOBACKUP_CONFIG" ]; then
                    backup_bot_token=$(grep '^bot_token:' "$AUTOBACKUP_CONFIG" 2>/dev/null | cut -d: -f2- | tr -d ' ')
                fi
                local current_hint=""
                [ -n "$backup_bot_token" ] && current_hint=" (Enter = оставить текущий)"
                tput cnorm 2>/dev/null || true
                reading_inline "Токен бота для бекапов${current_hint}:" new_backup_token
                if [ -z "$new_backup_token" ] && [ -n "$backup_bot_token" ]; then
                    new_backup_token="$backup_bot_token"
                fi
                if [ -z "$new_backup_token" ]; then
                    print_error "Токен не может быть пустым"
                    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                    read -p ""
                    continue
                fi

                # Chat ID
                local backup_chat_id=""
                if [ -f "$AUTOBACKUP_CONFIG" ]; then
                    backup_chat_id=$(grep '^chat_id:' "$AUTOBACKUP_CONFIG" 2>/dev/null | cut -d: -f2- | tr -d ' ')
                fi
                current_hint=""
                [ -n "$backup_chat_id" ] && current_hint=" (Enter = оставить текущий)"
                reading_inline "Telegram ID для получения бекапов${current_hint}:" new_chat_id
                if [ -z "$new_chat_id" ] && [ -n "$backup_chat_id" ]; then
                    new_chat_id="$backup_chat_id"
                fi
                if [ -z "$new_chat_id" ]; then
                    print_error "ID не может быть пустым"
                    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                    read -p ""
                    continue
                fi

                # Частота
                echo
                show_arrow_menu "Частота бекапа" \
                    "⏱️   Каждый час" \
                    "📅  Каждый день (00:00 МСК)" \
                    "📆  Каждую неделю (Вс 00:00 МСК)" \
                    "🗓️   Каждый месяц (1-е число, 00:00 МСК)"
                local freq_choice=$?

                local frequency=""
                case $freq_choice in
                    0) frequency="hourly" ;;
                    1) frequency="daily" ;;
                    2) frequency="weekly" ;;
                    3) frequency="monthly" ;;
                    255) continue ;;
                esac

                # Сохраняем конфиг
                cat > "$AUTOBACKUP_CONFIG" << EOF
bot_token: $new_backup_token
chat_id: $new_chat_id
frequency: $frequency
EOF

                # Создаём скрипт бекапа
                _create_autobackup_script "$new_backup_token" "$new_chat_id"

                # Устанавливаем cron
                local cron_schedule
                cron_schedule=$(_get_cron_schedule "$frequency")
                (crontab -l 2>/dev/null | grep -v "$AUTOBACKUP_SCRIPT"; echo "$cron_schedule $AUTOBACKUP_SCRIPT") | crontab -

                clear
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${GREEN}       💾 АВТОБЕКАП НАСТРОЕН${NC}"
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo
                echo -e "${GREEN}✅ Автобекап успешно настроен${NC}"
                echo
                local freq_label
                case $frequency in
                    hourly)  freq_label="Каждый час" ;;
                    daily)   freq_label="Каждый день (00:00 МСК)" ;;
                    weekly)  freq_label="Каждую неделю (Вс 00:00 МСК)" ;;
                    monthly) freq_label="Каждый месяц (1-е число, 00:00 МСК)" ;;
                esac
                echo -e "  Частота: ${YELLOW}${freq_label}${NC}"
                echo -e "  Получатель: ${YELLOW}${new_chat_id}${NC}"
                echo
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                ;;
            1)
                if _autobackup_is_active; then
                    # Создать бекап сейчас
                    local mn_token mn_chat
                    mn_token=$(grep '^bot_token:' "$AUTOBACKUP_CONFIG" 2>/dev/null | cut -d: -f2- | tr -d ' ')
                    mn_chat=$(grep '^chat_id:' "$AUTOBACKUP_CONFIG" 2>/dev/null | cut -d: -f2- | tr -d ' ')

                    clear
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${GREEN}       📤 СОЗДАНИЕ БЕКАПА${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo

                    local mn_ts mn_dump mn_dir mn_final mn_tmp
                    mn_ts=$(date +%Y-%m-%d_%H-%M)
                    mn_tmp="/tmp/_rs_backup_$$"
                    mkdir -p "$mn_tmp"
                    mn_dump="${mn_tmp}/dump_${mn_ts}.sql.gz"
                    mn_dir="${mn_tmp}/dir_${mn_ts}.tar.gz"
                    mn_final="${mn_tmp}/Remnasale_${mn_ts}.tar.gz"

                    (
                        docker exec remnasale-db pg_dumpall -c -U postgres 2>/dev/null | gzip -9 > "$mn_dump"
                    ) &
                    show_spinner "Создание дампа базы данных"

                    if [ ! -s "$mn_dump" ]; then
                        print_error "Не удалось создать дамп"
                        rm -rf "$mn_tmp"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        continue
                    fi

                    (
                        tar -czf "$mn_dir" --exclude='*.log' --exclude='*.tmp' --exclude='.git' --exclude='backups' -C /opt remnasale 2>/dev/null || true
                    ) &
                    show_spinner "Архивирование директории"

                    (
                        tar -czf "$mn_final" -C "$mn_tmp" "$(basename "$mn_dump")" "$(basename "$mn_dir")" 2>/dev/null
                    ) &
                    show_spinner "Создание финального архива"
                    rm -f "$mn_dump" "$mn_dir" 2>/dev/null

                    if [ ! -s "$mn_final" ]; then
                        print_error "Не удалось создать архив"
                        rm -rf "$mn_tmp"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        continue
                    fi

                    local mn_size
                    mn_size=$(du -h "$mn_final" | awk '{print $1}')
                    local mn_date
                    mn_date=$(date '+%d.%m.%Y %H:%M')
                    local mn_caption
                    mn_caption="💾 #remnasale_backup
➖➖➖➖➖➖➖➖➖
✅ Бекап создан вручную
📁 БД + Директория
📏 Размер: ${mn_size}
📅 ${mn_date} MSK"

                    (
                        curl -s \
                            -F "chat_id=$mn_chat" \
                            -F "document=@$mn_final" \
                            -F "caption=$mn_caption" \
                            "https://api.telegram.org/bot${mn_token}/sendDocument" > /tmp/_rs_ab_result 2>&1
                    ) &
                    show_spinner "Отправка в Telegram"

                    local send_ok=false
                    grep -q '"ok":true' /tmp/_rs_ab_result 2>/dev/null && send_ok=true
                    rm -f /tmp/_rs_ab_result 2>/dev/null || true
                    rm -rf "$mn_tmp" 2>/dev/null || true

                    if $send_ok; then
                        print_success "Бекап успешно отправлен в Telegram"
                        echo -e "  📏 Размер: ${YELLOW}${mn_size}${NC}"
                    else
                        print_error "Не удалось отправить бекап (проверьте токен/chat_id)"
                    fi
                    echo
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                    read -p ""
                else
                    return
                fi
                ;;
            2)
                if _autobackup_is_active; then
                    # Остановить автобекап
                    (crontab -l 2>/dev/null | grep -v "$AUTOBACKUP_SCRIPT") | crontab -
                    rm -f "$AUTOBACKUP_CONFIG" 2>/dev/null || true
                    clear
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${GREEN}       💾 АВТОБЕКАП${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo
                    echo -e "${GREEN}✅ Автобекап остановлен${NC}"
                    echo
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                    read -p ""
                else
                    return
                fi
                ;;
            *) return ;;
        esac
    done
}

# Функция обновления бота
manage_update_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}       🔄 ОБНОВЛЕНИЕ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    
    # Сохраняем позицию курсора перед выводом информации о проверке
    tput sc 2>/dev/null || true
    
    # Скрываем курсор во время проверки
    tput civis 2>/dev/null || true
    
    # Создаём временную папку для клонирования репозитория
    TEMP_REPO=$(mktemp -d)
    
    # Проверка обновлений с спинером
    show_spinner "Проверка обновлений" &
    SPINNER_PID=$!
    
    git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$TEMP_REPO" >/dev/null 2>&1
    
    # Убиваем спинер после завершения клонирования
    kill $SPINNER_PID 2>/dev/null || true
    wait $SPINNER_PID 2>/dev/null || true
    
    # Получаем версии (из файла version)
    REMOTE_VERSION=$(parse_version_from_content "$(cat "$TEMP_REPO/version" 2>/dev/null)")
    LOCAL_VERSION=$(get_local_version)
    
    UPDATE_NEEDED=1
    
    # Проверяем версии
    if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ]; then
        # Сравниваем семантически — обновление нужно ТОЛЬКО если remote > local
        local_num=$(echo "$LOCAL_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
        remote_num=$(echo "$REMOTE_VERSION" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
        if [ "$remote_num" -le "$local_num" ]; then
            UPDATE_NEEDED=0
        fi
    else
        # Fallback на старый метод с хешами если версии не доступны
        REMOTE_HASH=$(cd "$TEMP_REPO" && git rev-parse HEAD 2>/dev/null)
        LOCAL_HASH=""
        
        if [ -f "$ENV_FILE" ] && grep -q "^LAST_UPDATE_HASH=" "$ENV_FILE"; then
            LOCAL_HASH=$(grep "^LAST_UPDATE_HASH=" "$ENV_FILE" | cut -d'=' -f2)
            
            if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
                UPDATE_NEEDED=0
            fi
        elif [ -d "$PROJECT_DIR/.git" ]; then
            # Если это git репозиторий, просто сравним хеши
            LOCAL_HASH=$(cd "$PROJECT_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
            
            if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
                UPDATE_NEEDED=0
            fi
        else
            # Если нет .git и нет сохранённого хеша - нужно обновить
            UPDATE_NEEDED=1
        fi
    fi
    
    # Выводим результат проверки
    if [ $UPDATE_NEEDED -eq 0 ]; then
        clear
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${GREEN}       🔄 ОБНОВЛЕНИЕ REMNASALE${NC}"
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo
        echo -e "${GREEN}✅ Уже установлена последняя версия бота!${NC}"
        echo
        if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "unknown" ]; then
            echo -e "   Текущая версия:  ${CYAN}v${LOCAL_VERSION}${NC}"
        fi
        if [ -n "$REMOTE_VERSION" ]; then
            echo -e "   Версия GitHub:   ${CYAN}v${REMOTE_VERSION}${NC}"
        fi
        echo
        echo -e "${GRAY}Нажмите Enter для возврата в меню...${NC}"
        read -r
        rm -rf "$TEMP_REPO" 2>/dev/null || true
        return
    else
        # Автоматическое начало обновления без диалога
        clear
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo -e "${GREEN}       🔄 ОБНОВЛЕНИЕ REMNASALE${NC}"
        echo -e "${BLUE}══════════════════════════════════════${NC}"
        echo
        if [ -n "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "unknown" ]; then
            echo -e "   Текущая версия:  ${CYAN}v${LOCAL_VERSION}${NC}"
        fi
        if [ -n "$REMOTE_VERSION" ]; then
            echo -e "   Новая версия:    ${GREEN}v${REMOTE_VERSION}${NC}"
        fi
        echo
        echo -e "${YELLOW}🚀 Запуск обновления...${NC}"
        echo
        echo -e "${BLUE}──────────────────────────────────────${NC}"
        echo
        # Сохраняем критические переменные перед обновлением
        ENV_BACKUP_FILE=$(preserve_env_vars "$ENV_FILE")
            
            # Копируем только необходимые файлы конфигурации в PROJECT_DIR
            {
                cd "$TEMP_REPO" || return
                
                # Список файлов для копирования в PROJECT_DIR (только конфигурация)
                INCLUDE_FILES=(
                    "docker-compose.yml"
                    "assets"
                )
                
                for item in "${INCLUDE_FILES[@]}"; do
                    if [ -e "$item" ]; then
                        if [ -d "$item" ]; then
                            mkdir -p "$PROJECT_DIR/$item" 2>/dev/null || true
                            # Копируем всё содержимое
                            if [ "$item" = "assets" ]; then
                                # Для папки assets копируем всё содержимое
                                for subitem in "$item"/*; do
                                    subname=$(basename "$subitem")
                                    if [ -d "$subitem" ]; then
                                        # Для папки banners - копируем только если папка не существует
                                        if [ "$subname" = "banners" ]; then
                                            if [ ! -d "$PROJECT_DIR/$item/banners" ]; then
                                                cp -r "$subitem" "$PROJECT_DIR/$item/" 2>/dev/null || true
                                            else
                                                # Папка существует, копируем всё кроме default.jpg (пользовательский баннер)
                                                for banner_file in "$subitem"/*; do
                                                    banner_name=$(basename "$banner_file")
                                                    if [ "$banner_name" != "default.jpg" ]; then
                                                        if [ -f "$banner_file" ]; then
                                                            cp -f "$banner_file" "$PROJECT_DIR/$item/banners/" 2>/dev/null || true
                                                        fi
                                                    fi
                                                done
                                            fi
                                        else
                                            cp -r "$subitem" "$PROJECT_DIR/$item/" 2>/dev/null || true
                                        fi
                                    else
                                        cp -f "$subitem" "$PROJECT_DIR/$item/" 2>/dev/null || true
                                    fi
                                done
                            else
                                cp -r "$item"/* "$PROJECT_DIR/$item/" 2>/dev/null || true
                            fi
                        else
                            cp -f "$item" "$PROJECT_DIR/" 2>/dev/null || true
                        fi
                    fi
                done
                
                # Копируем файл версии из временного репозитория
                if [ -f "version" ]; then
                    cp -f "version" "$PROJECT_DIR/version"
                fi
                
                # Копируем remnasale-install.sh в системную папку (не в корень бота)
                sudo mkdir -p "$SYSTEM_INSTALL_DIR" 2>/dev/null || true
                _src="$(realpath "remnasale-install.sh" 2>/dev/null || echo "remnasale-install.sh")"
                _dst="$(realpath "$SYSTEM_INSTALL_DIR/remnasale-install.sh" 2>/dev/null || echo "$SYSTEM_INSTALL_DIR/remnasale-install.sh")"
                if [ "$_src" != "$_dst" ]; then
                    sudo cp -f "remnasale-install.sh" "$SYSTEM_INSTALL_DIR/remnasale-install.sh" 2>/dev/null || true
                fi
                sudo chmod +x "$SYSTEM_INSTALL_DIR/remnasale-install.sh" 2>/dev/null || true
            } &
            show_spinner "Обновление конфигурации"
            
            {
                cd "$PROJECT_DIR" || return
                docker compose down >/dev/null 2>&1
            } &
            show_spinner "Остановка сервисов"
            
            {
                # Собираем образ из временной папки с исходниками
                cd "$TEMP_REPO" || return
                docker build -t remnasale:local \
                    --build-arg BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    --build-arg BUILD_BRANCH="$REPO_BRANCH" \
                    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
                    --build-arg BUILD_TAG="$(grep '^version:' version 2>/dev/null | cut -d: -f2 | tr -d ' \n' || echo 'unknown')" \
                    . >/dev/null 2>&1
            } &
            show_spinner "Пересборка образа"
            
            # Восстанавливаем сохранённые переменные в .env после обновления (до запуска контейнеров)
            if [ -n "$ENV_BACKUP_FILE" ] && [ -f "$ENV_BACKUP_FILE" ]; then
                {
                    restore_env_vars "$ENV_FILE" "$ENV_BACKUP_FILE"
                } &
                show_spinner "Применение сохранённых параметров"
            fi
            
            # Запускаем контейнеры и ожидаем запуска бота
            cd "$PROJECT_DIR" || return
            docker compose up -d >/dev/null 2>&1
            
            echo
            
            # Ждем появления логотипа Remnasale в логах
            show_spinner_until_log "remnasale" "Digital.*Freedom.*Core" "Запуск бота" 90
            local spinner_result=$?
            
            echo
            
            if [ $spinner_result -eq 0 ]; then
                echo -e "${GREEN}✅ Бот успешно обновлен${NC}"
                
                # Сохраняем хеш обновления в .env
                update_env_var "$ENV_FILE" "LAST_UPDATE_HASH" "$REMOTE_HASH"
                
                # Удаляем временную папку репозитория
                rm -rf "$TEMP_REPO" 2>/dev/null || true
                
                echo
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                
                # Перезапускаем скрипт чтобы вернуться в главное меню
                # При перезапуске check_updates_available автоматически пересчитает флаг обновления
                restart_script
            elif [ $spinner_result -eq 2 ]; then
                echo -e "${RED}❌ Ошибка при обновлении бота!${NC}"
                echo
                echo -ne "${YELLOW}Показать лог ошибки? [Y/n]: ${NC}"
                read -n 1 -r show_logs
                echo
                
                if [[ -z "$show_logs" || "$show_logs" =~ ^[Yy]$ ]]; then
                    echo
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${RED}ЛОГИ ОШИБОК:${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    docker compose -f "$PROJECT_DIR/docker-compose.yml" logs --tail 50 remnasale
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                fi
                
                # Удаляем временную папку репозитория
                rm -rf "$TEMP_REPO" 2>/dev/null || true
                
                echo
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                return
            else
                echo -e "${YELLOW}Бот может всё ещё запускаться...${NC}"
                
                # Сохраняем хеш обновления даже при таймауте
                update_env_var "$ENV_FILE" "LAST_UPDATE_HASH" "$REMOTE_HASH"
                
                # Удаляем временную папку репозитория
                rm -rf "$TEMP_REPO" 2>/dev/null || true
                
                echo
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                
                # Перезапускаем скрипт
                restart_script
            fi
    fi
    
    # Очистка временной папки репозитория в конце функции (на случай если не прошли через exec)
    rm -rf "$TEMP_REPO" 2>/dev/null || true
}

# Функция перезагрузки бота с ожиданием логотипа Remnasale
manage_restart_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}      🔃 ПЕРЕЗАГРУЗКА REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Бот будет перезагружен...${NC}"
    echo
    
    {
        cd "$PROJECT_DIR" || return
        docker compose down >/dev/null 2>&1
        docker compose up -d >/dev/null 2>&1
    } &
    show_spinner "Перезагрузка бота"
    
    # Ждем появления логотипа Remnasale в логах
    show_spinner_until_log "remnasale" "Digital.*Freedom.*Core" "Запуск бота" 90
    local spinner_result=$?
    
    echo
    if [ $spinner_result -eq 2 ]; then
        echo -e "${RED}❌ Обнаружена ошибка при запуске. Проверьте логи.${NC}"
    else
        echo -e "${GREEN}✅Бот успешно обновлен и запущен!${NC}"
    fi
    
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    tput cnorm 2>/dev/null || true
    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
    read -p ""
}

# Функция перезагрузки бота с отображением логов
manage_restart_bot_with_logs() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}    🔃📊 ПЕРЕЗАГРУЗКА С ЛОГАМИ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Бот будет перезагружен с отображением логов...${NC}"
    echo -e "${DARKGRAY}(Нажмите Ctrl+C для выхода из логов)${NC}"
    echo
    
    # Восстанавливаем нормальные настройки терминала
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    
    cd "$PROJECT_DIR" || return
    
    # Перезагружаем и одновременно смотрим логи
    docker compose down >/dev/null 2>&1
    docker compose up -d >/dev/null 2>&1
    sleep 2
    
    # Выводим логи с автоматическим обновлением
    # Перехватываем Ctrl+C чтобы не завершать весь скрипт
    trap '' INT
    docker compose logs -f remnasale
    trap handle_interrupt INT
    
    # После выхода из логов возвращаемся в меню
    echo
    echo -e "${DARKGRAY}Отображение логов остановлено${NC}"
    echo
    tput civis 2>/dev/null || true
    echo -e "${DARKGRAY}Нажмите Enter для возврата в меню${NC}"
    read -p ""
}

# Функция переустановки бота с удалением всех данных
manage_reinstall_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}      🔄 ПЕРЕУСТАНОВКА REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${RED}⚠️  ВНИМАНИЕ!${NC}"
    echo -e "${RED}Это действие удалит весь бот и ВСЕ данные:${NC}"
    echo -e "  - База данных PostgreSQL"
    echo -e "  - Redis/Valkey"
    echo -e "  - Все конфигурационные файлы"
    echo -e "  - Логи и кэш"
    echo
    echo -e "${YELLOW}После этого будет произведена чистая переустановка бота.${NC}"
    echo
    
    if ! confirm_action; then
        return
    fi
    
    echo
    
    # Удаляем контейнеры и данные
    {
        cd "$PROJECT_DIR" || return
        docker compose down -v >/dev/null 2>&1 || true
        
        # Удаляем все локальные данные
        rm -rf "$PROJECT_DIR/db_data" 2>/dev/null || true
        rm -rf "$PROJECT_DIR/redis_data" 2>/dev/null || true
        rm -rf "$PROJECT_DIR/.env" 2>/dev/null || true
    } &
    show_spinner "Удаление данных и контейнеров"
    
    echo
    
    # Запускаем переустановку
    if confirm_action "Начать переустановку?"; then
        # Восстанавливаем нормальные настройки терминала
        stty sane 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        
        # Запускаем скрипт установки
        restart_script --install
    else
        echo -e "${YELLOW}Переустановка отменена${NC}"
        echo
        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
        read -p ""
        tput civis 2>/dev/null || true
    fi
}

# Функция выключения бота
manage_stop_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}      ⬇️  ВЫКЛЮЧЕНИЕ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Бот будет выключен...${NC}"
    echo
    
    {
        cd "$PROJECT_DIR" || return
        docker compose down >/dev/null 2>&1
    } &
    show_spinner "Выключение бота"
    
    echo
    echo -e "${GREEN}✅ Бот успешно выключен${NC}"
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    tput civis 2>/dev/null || true
    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
    read -p ""
}

# Функция включения бота
manage_start_bot() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}      ⬆️  ВКЛЮЧЕНИЕ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Бот будет включен...${NC}"
    echo
    
    {
        cd "$PROJECT_DIR" || return
        docker compose up -d >/dev/null 2>&1
    } &
    show_spinner "Включение бота"
    
    echo
    echo -e "${GREEN}✅ Бот успешно включен${NC}"
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    tput civis 2>/dev/null || true
    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
    read -p ""
}

# Функция просмотра логов
manage_view_logs() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}       📋 ПРОСМОТР ЛОГОВ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${DARKGRAY}Последние 50 строк логов...${NC}"
    echo -e "${DARKGRAY}(Нажмите Enter для продолжения)${NC}"
    echo
    
    cd "$PROJECT_DIR" || return
    docker compose logs remnasale 2>&1 | tail -50
    
    echo
    tput civis 2>/dev/null || true
    echo -e "${DARKGRAY}Нажмите Enter для возврата в меню${NC}"
    read -p ""
}

# Функция просмотра логов в реальном времени
manage_view_logs_live() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}     📊 ЛОГИ В РЕАЛЬНОМ ВРЕМЕНИ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${DARKGRAY}Запуск просмотра логов...${NC}"
    echo -e "${DARKGRAY}(Для выхода нажмите Ctrl+C)${NC}"
    echo
    
    # Восстанавливаем нормальные настройки терминала
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    
    cd "$PROJECT_DIR" || return
    
    # Перехватываем Ctrl+C чтобы не завершать весь скрипт
    trap '' INT
    docker compose logs -f remnasale
    trap handle_interrupt INT
    
    # После выхода возвращаемся в raw mode
    tput civis 2>/dev/null || true
    echo
    echo -e "${DARKGRAY}Отображение логов остановлено${NC}"
    echo
    echo -e "${DARKGRAY}Нажмите Enter для возврата в меню${NC}"
    read -p ""
}

# Функция изменения настроек
manage_change_settings() {
    while true; do
        show_arrow_menu "⚙️  ИЗМЕНЕНИЕ НАСТРОЕК" \
            "🌐 Изменить домен" \
            "🤖 Изменить Токен телеграм бота" \
            "👤 Изменить Телеграм ID разработчика" \
            "──────────────────────────────────────" \
            "⬅️  Назад"
        local choice=$?
        
        case $choice in
            4|255)  # Назад / Esc
                return
                ;;
            0)  # Изменить домен
                while true; do
                    clear
                    tput civis 2>/dev/null || true
                    
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${GREEN}       🌐 ИЗМЕНИТЬ ДОМЕН${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Введите новые данные или нажмите Esc для отмены${NC}"
                    echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                    echo
                    echo "Текущее значение: $(grep "^APP_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2)"
                    
                    # Используем read с опцией -p для защиты промпта от удаления
                    tput cnorm 2>/dev/null || true
                    read -e -p $'\e[33mВведите новый домен:\e[0m ' new_domain
                    
                    tput civis 2>/dev/null || true
                    echo
                    
                    if [ -z "$new_domain" ]; then
                        echo -e "${YELLOW}ℹ️  Отменено${NC}"
                        echo
                        echo -e "${BLUE}══════════════════════════════════════${NC}"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        break
                    fi

                    # Проверяем привязку домена к IP сервера
                    if ! check_domain "$new_domain"; then
                        echo
                        echo -e "${DARKGRAY}Нажмите Enter чтобы ввести другой домен, или Esc для отмены.${NC}"
                        local key
                        while true; do
                            read -s -n 1 key
                            if [[ "$key" == $'\x1b' ]]; then
                                break 2
                            elif [[ "$key" == "" ]]; then
                                continue 2
                            fi
                        done
                    fi

                    # Проверяем, не занят ли домен другим сервисом
                    local domain_in_use=false
                    local new_domain_escaped_check
                    new_domain_escaped_check=$(printf '%s' "$new_domain" | sed 's/[.[\/\*^$]/\\&/g')
                    if [ -f "/opt/remnawave/nginx.conf" ]; then
                        local old_current
                        old_current=$(grep "^APP_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2)
                        # Проверяем есть ли server_name с таким доменом, не принадлежащий боту
                        if grep -q "server_name ${new_domain_escaped_check};" /opt/remnawave/nginx.conf 2>/dev/null; then
                            domain_in_use=true
                        fi
                    fi
                    if [ -f "/opt/remnawave/caddy/Caddyfile" ] && grep -q "https://${new_domain_escaped_check}" /opt/remnawave/caddy/Caddyfile 2>/dev/null; then
                        domain_in_use=true
                    fi
                    if [ "$domain_in_use" = true ]; then
                        echo -e "${RED}✖ Домен ${YELLOW}$new_domain${RED} уже используется другим сервисом на этом сервере${NC}"
                        echo -e "${RED}⚠️  Укажите другой домен, который не занят.${NC}"
                        echo
                        echo -e "${DARKGRAY}Нажмите Enter чтобы ввести другой домен, или Esc для отмены.${NC}"
                        local key
                        while true; do
                            read -s -n 1 key
                            if [[ "$key" == $'\x1b' ]]; then
                                break 2
                            elif [[ "$key" == "" ]]; then
                                continue 2
                            fi
                        done
                    fi

                    echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                    echo
                    {
                        old_domain=$(grep "^APP_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2)
                        update_env_var "$ENV_FILE" "APP_DOMAIN" "$new_domain" >/dev/null 2>&1
                        update_env_var "$ENV_FILE" "BOT_MINI_APP" "https://${new_domain}/web/miniapp" >/dev/null 2>&1
                        
                        # Обновляем Caddyfile в /opt/remnawave/caddy/
                        if [ -f "/opt/remnawave/caddy/Caddyfile" ]; then
                            old_domain_escaped=$(printf '%s\n' "$old_domain" | sed -e 's/[\.]/\\&/g')
                            new_domain_escaped=$(printf '%s\n' "$new_domain" | sed -e 's/[\/&]/\\&/g')
                            sed -i "s/https:\/\/$old_domain_escaped/https:\/\/$new_domain_escaped/g" /opt/remnawave/caddy/Caddyfile 2>/dev/null || true
                            # Перезапускаем Caddy
                            cd /opt/remnawave && docker compose restart caddy >/dev/null 2>&1 || true
                        fi
                        
                        # Обновляем nginx.conf: заменяем server_name и пути к сертификатам
                        if [ -f "/opt/remnawave/nginx.conf" ]; then
                            old_domain_escaped=$(printf '%s\n' "$old_domain" | sed -e 's/[.[\/\*^$]/\\&/g')
                            new_domain_escaped=$(printf '%s\n' "$new_domain" | sed -e 's/[.[\/\*^$]/\\&/g')
                            sed -i "s/server_name ${old_domain_escaped};/server_name ${new_domain_escaped};/g" /opt/remnawave/nginx.conf 2>/dev/null || true
                            sed -i "s|/etc/letsencrypt/live/${old_domain_escaped}/|/etc/letsencrypt/live/${new_domain_escaped}/|g" /opt/remnawave/nginx.conf 2>/dev/null || true

                            # Получаем SSL-сертификат если его нет
                            if [ ! -d "/etc/letsencrypt/live/$new_domain" ]; then
                                if [ -f "/etc/letsencrypt/cloudflare.ini" ]; then
                                    cert_base_domain=$(echo "$new_domain" | awk -F. '{print $(NF-1)"."$NF}')
                                    cert_base_escaped=$(printf '%s\n' "$cert_base_domain" | sed -e 's/[.[\/*^$]/\\&/g')
                                    if [ -d "/etc/letsencrypt/live/$cert_base_domain" ]; then
                                        sed -i "s|/etc/letsencrypt/live/${new_domain_escaped}/|/etc/letsencrypt/live/${cert_base_escaped}/|g" /opt/remnawave/nginx.conf 2>/dev/null || true
                                    else
                                        certbot certonly --dns-cloudflare \
                                            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
                                            --dns-cloudflare-propagation-seconds 30 \
                                            -d "$cert_base_domain" -d "*.$cert_base_domain" \
                                            --email "admin@$cert_base_domain" --agree-tos --non-interactive \
                                            --key-type ecdsa >/dev/null 2>&1 || true
                                        sed -i "s|/etc/letsencrypt/live/${new_domain_escaped}/|/etc/letsencrypt/live/${cert_base_escaped}/|g" /opt/remnawave/nginx.conf 2>/dev/null || true
                                    fi
                                else
                                    ufw allow 80/tcp >/dev/null 2>&1 || true
                                    certbot certonly --standalone \
                                        -d "$new_domain" \
                                        --email "admin@$new_domain" --agree-tos --non-interactive \
                                        --http-01-port 80 \
                                        --key-type ecdsa >/dev/null 2>&1 || true
                                    ufw delete allow 80/tcp >/dev/null 2>&1 || true
                                    ufw reload >/dev/null 2>&1 || true
                                fi
                            fi

                            cd /opt/remnawave && docker compose restart remnawave-nginx >/dev/null 2>&1 || true
                        fi

                        # Обновляем WEBHOOK_URL в /opt/remnawave/.env
                        if [ -f "/opt/remnawave/.env" ]; then
                            local old_webhook_escaped
                            old_webhook_escaped=$(printf '%s\n' "$old_domain" | sed -e 's/[.[\/*^$]/\\&/g')
                            local new_webhook_escaped
                            new_webhook_escaped=$(printf '%s\n' "$new_domain" | sed -e 's/[.[\/*^$]/\\&/g')
                            sed -i "s|${old_webhook_escaped}|${new_webhook_escaped}|g" /opt/remnawave/.env 2>/dev/null || true
                            # Пересоздаём remnawave для применения нового WEBHOOK_URL
                            cd /opt/remnawave && docker compose up -d --force-recreate remnawave >/dev/null 2>&1 || true
                        fi
                    } &
                    show_spinner "Обновление домена"
                    
                    # Очищаем webhook lock в Redis чтобы бот переустановил webhook
                    local redis_pass
                    redis_pass=$(grep "^REDIS_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)
                    if [ -n "$redis_pass" ]; then
                        cd "$PROJECT_DIR" && docker compose exec -T remnasale-redis redis-cli -a "$redis_pass" keys "*webhook_lock*" 2>/dev/null | grep -v "^Warning" | while read -r key; do
                            docker compose exec -T remnasale-redis redis-cli -a "$redis_pass" del "$key" >/dev/null 2>&1
                        done
                    fi

                    # Пересоздаём бота для применения нового домена
                    cd "$PROJECT_DIR" && docker compose up -d --force-recreate remnasale >/dev/null 2>&1
                    
                    # Ждём запуска бота
                    show_spinner_until_log "remnasale" "Digital.*Freedom.*Core" "Перезагрузка бота" 90
                    local spinner_result=$?
                    
                    echo
                    if [ $spinner_result -eq 0 ]; then
                        echo -e "${GREEN}✅ Домен обновлён${NC}"
                        echo -e "${GREEN}✅ Бот запущен${NC}"
                    elif [ $spinner_result -eq 2 ]; then
                        echo -e "${GREEN}✅ Домен обновлён${NC}"
                        echo -e "${RED}❌ Обнаружена ошибка при запуске бота. Проверьте логи.${NC}"
                    else
                        echo -e "${GREEN}✅ Домен обновлён${NC}"
                        echo -e "${YELLOW}⚠️  Бот запускается (таймаут ожидания истёк)${NC}"
                    fi
                    echo
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                    read -p ""
                    break
                done
                ;;
            1)  # Изменить Токен телеграм бота
                while true; do
                    clear
                    tput civis 2>/dev/null || true
                    
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${GREEN}       🤖 ИЗМЕНИТЬ ТОКЕН ТЕЛЕГРАМ БОТА${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Введите новые данные или нажмите Esc для отмены${NC}"
                    echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                    echo
                    echo "Текущее значение: (скрыто)"
                    
                    # Используем read с опцией -p для защиты промпта от удаления
                    tput cnorm 2>/dev/null || true
                    read -e -p $'\e[33mВведите новый токен:\e[0m ' new_token
                    
                    tput civis 2>/dev/null || true
                    echo
                    
                    if [ -z "$new_token" ]; then
                        echo -e "${YELLOW}ℹ️  Отменено${NC}"
                        echo
                        echo -e "${BLUE}══════════════════════════════════════${NC}"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        break
                    else
                        echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                        echo
                        {
                            update_env_var "$ENV_FILE" "BOT_TOKEN" "$new_token" >/dev/null 2>&1
                        } &
                        show_spinner "Обновление токена"
                        
                        {
                            cd "$PROJECT_DIR" || return
                            docker compose down >/dev/null 2>&1
                            docker compose up -d >/dev/null 2>&1
                        } &
                        show_spinner "Перезагрузка сервисов"
                        echo -e "${GREEN}✅ Токен обновлён и сервисы перезагружены${NC}"
                        echo
                        echo -e "${BLUE}══════════════════════════════════════${NC}"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        break
                    fi
                done
                ;;
            2)  # Изменить Телеграм ID разработчика
                while true; do
                    clear
                    tput civis 2>/dev/null || true
                    
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${GREEN}       👤 ИЗМЕНИТЬ ТЕЛЕГРАМ ID РАЗРАБОТЧИКА${NC}"
                    echo -e "${BLUE}══════════════════════════════════════${NC}"
                    echo -e "${DARKGRAY}Введите новые данные или нажмите Esc для отмены${NC}"
                    echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                    echo
                    echo "Текущее значение: $(grep "^BOT_DEV_ID=" "$ENV_FILE" | cut -d'=' -f2)"
                    
                    # Используем read с опцией -p для защиты промпта от удаления
                    tput cnorm 2>/dev/null || true
                    read -e -p $'\e[33mВведите новый ID:\e[0m ' new_dev_id
                    
                    tput civis 2>/dev/null || true
                    echo
                    
                    if [ -z "$new_dev_id" ]; then
                        echo -e "${YELLOW}ℹ️  Отменено${NC}"
                        echo
                        echo -e "${BLUE}══════════════════════════════════════${NC}"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        break
                    else
                        echo -e "${DARKGRAY}──────────────────────────────────────${NC}"
                        echo
                        {
                            update_env_var "$ENV_FILE" "BOT_DEV_ID" "$new_dev_id" >/dev/null 2>&1
                        } &
                        show_spinner "Обновление ID разработчика"
                        echo -e "${GREEN}✅ ID обновлён${NC}"
                        echo
                        echo -e "${BLUE}══════════════════════════════════════${NC}"
                        echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                        read -p ""
                        break
                    fi
                done
                ;;
        esac
    done
}

# Функция очистки базы данных
manage_cleanup_database() {
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}       🧹 ОЧИСТКА БАЗЫ ДАННЫХ${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${RED}⚠️  Внимание!${NC} Это удалит всех пользователей и данные!"
    echo
    
    if ! confirm_action; then
        return
    fi
    
    echo
    
    # PostgreSQL
    {
        if command -v psql &> /dev/null; then
            psql -h 127.0.0.1 -U "$(grep "^DB_USER=" "$ENV_FILE" | cut -d= -f2 | tr -d '\"')" \
                -d "$(grep "^DB_NAME=" "$ENV_FILE" | cut -d= -f2 | tr -d '\"')" \
                -c "DELETE FROM users;" >/dev/null 2>&1 || true
        fi
    } &
    show_spinner "Очистка базы данных"
    
    # Redis
    {
        if command -v redis-cli &> /dev/null; then
            redis-cli FLUSHALL >/dev/null 2>&1 || true
        fi
    } &
    show_spinner "Очистка кэша"
    
    echo
    echo -e "${GREEN}✅ Данные успешно очищены${NC}"
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
    read -p ""
}

# Функция удаления бота
manage_uninstall_bot() {
    cd /opt || true
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}       🗑️  УДАЛЕНИЕ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${RED}⚠️  Внимание!${NC} Это удалит бота и все его данные!"
    echo
    
    if ! confirm_action; then
        return
    fi
    
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}       🗑️  УДАЛЕНИЕ REMNASALE${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    
    # Подготовка к удалению (очистка реверс-прокси)
    {
        remove_from_caddy >/dev/null 2>&1 || true
        remove_from_nginx >/dev/null 2>&1 || true
    } &
    show_spinner "Подготовка к удалению"
    
    # Остановка контейнеров и удаление
    {
        cd /opt
        if [ -d "$PROJECT_DIR" ]; then
            cd "$PROJECT_DIR" && docker compose down >/dev/null 2>&1 || true
            cd /opt
        fi
        rm -rf "$PROJECT_DIR"
    } &
    show_spinner "Удаление бота и контейнеров"
    
    # Удаляем глобальную команду
    {
        sudo rm -f /usr/local/bin/remnasale 2>/dev/null || true
        sudo rm -rf /usr/local/lib/remnasale 2>/dev/null || true
    } &
    show_spinner "Удаление ярлыка команды"
    
    echo
    echo -e "${GREEN}✅ Бот был успешно удален!${NC}"
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    printf "\033[?25l${DARKGRAY}${BLUE}Enter${DARKGRAY}: Продолжить${NC}"
    while true; do
        read -rs -n1 _k 2>/dev/null
        [[ "$_k" == "" ]] && break
    done
    printf "\033[?25h"
    echo
    clear
    exit 0
}

# Функция очистки при ошибке или отмене
cleanup_on_error() {
    local exit_code=$?
    
    # Показать курсор
    tput cnorm >/dev/null 2>&1 || true
    tput sgr0 >/dev/null 2>&1 || true
    
    # Очистка выполняется ТОЛЬКО если установка была начата (--install) и не завершена
    if [ "$INSTALL_STARTED" = "true" ] && [ "$INSTALL_COMPLETED" != "true" ]; then
        # Очищаем экран
        clear
        
        # Проверяем был ли это Ctrl+C (exit code 130)
        if [ $exit_code -eq 130 ]; then
            # Пользователь прервал скрипт
            echo -e "${BLUE}══════════════════════════════════════${NC}"
            echo -e "${YELLOW}  ⚠️  УСТАНОВКА ПРЕРВАНА ПОЛЬЗОВАТЕЛЕМ${NC}"
            echo -e "${BLUE}══════════════════════════════════════${NC}"
        else
            # Ошибка установки
            echo -e "${RED}══════════════════════════════════════${NC}"
            echo -e "${RED}  ⚠️  ОШИБКА УСТАНОВКИ ПРИЛОЖЕНИЯ${NC}"
            echo -e "${RED}══════════════════════════════════════${NC}"
        fi
        echo
        
        # Удаляем исходную папку с клоном репозитория
        if [ -n "$SOURCE_DIR" ] && [ "$SOURCE_DIR" != "/opt/remnasale" ] && [ "$SOURCE_DIR" != "/" ] && [ -d "$SOURCE_DIR" ]; then
            rm -rf "$SOURCE_DIR" 2>/dev/null || true
        fi
        
        # Останавливаем контейнеры если они запущены
        if command -v docker &> /dev/null && [ -d "$PROJECT_DIR" ]; then
            cd "$PROJECT_DIR" 2>/dev/null && docker compose down >/dev/null 2>&1 || true
        fi
        
        # Удаляем папку /opt/remnasale при ошибке установки
        if [ -d "$PROJECT_DIR" ]; then
            rm -rf "$PROJECT_DIR" 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ Очистка временных файлов приложения${NC}"
        echo
        
        # Показываем совет только если это не было прерыванием пользователем
        if [ $exit_code -ne 130 ]; then
            echo -e "${WHITE}Попробуйте запустить установку снова${NC}"
            echo
        fi
    fi
    
    # Удаляем временную папку клонирования если она была создана
    if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
        cd /opt 2>/dev/null || true
        rm -rf "$CLONE_DIR" 2>/dev/null || true
    fi
    
    # Удаляем временную папку TEMP_REPO если она была создана
    if [ -n "$TEMP_REPO" ] && [ -d "$TEMP_REPO" ]; then
        rm -rf "$TEMP_REPO" 2>/dev/null || true
    fi
    
    # Удаляем временную папку TEMP_CHECK_DIR если она была создана
    if [ -n "$TEMP_CHECK_DIR" ] && [ -d "$TEMP_CHECK_DIR" ]; then
        rm -rf "$TEMP_CHECK_DIR" 2>/dev/null || true
    fi
    
    exit $exit_code
}

# Установка trap для обработки ошибок, прерываний и выхода
trap cleanup_on_error EXIT
trap handle_interrupt INT TERM

# Автоматически даем права на выполнение самому себе
chmod +x "$0" 2>/dev/null || true

# Скрыть курсор
tput civis >/dev/null 2>&1 || true

# Режим установки: dev или prod
INSTALL_MODE="dev"

# Если это первый запуск (скрипт запущен из системы, не из временной папки)
if [ "$1" != "--install" ]; then
    # Проверяем режим если скрипт вызван без аргументов --install
    if [ "$1" != "--prod" ] && [ "$1" != "-p" ]; then
        check_mode "$1"
        exit $?
    fi
    
    if [ "$1" = "--prod" ] || [ "$1" = "-p" ]; then
        INSTALL_MODE="prod"
    fi
    
    # Проверяем что это не dev окружение (не должна быть .git папка в текущей директории)
    # Если это dev окружение - принудительно клонируем в temp
    CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -d "$CURRENT_DIR/.git" ] && [ "$CURRENT_DIR" != "/opt/remnasale" ]; then
        # Создаем временную папку и клонируем
        CLONE_DIR=$(mktemp -d)
        trap "cd /opt 2>/dev/null || true; rm -rf '$CLONE_DIR' 2>/dev/null || true" EXIT
        
        if ! git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1; then
            echo "❌ Ошибка при клонировании репозитория"
            exit 1
        fi
        
        chmod +x "$CLONE_DIR/remnasale-install.sh"
        cd "$CLONE_DIR"
        exec "$CLONE_DIR/remnasale-install.sh" --install "$CLONE_DIR" "$INSTALL_MODE"
    fi
    
    # Создаем временную папку с уникальным именем и переклонируемся туда
    CLONE_DIR=$(mktemp -d)
    trap "cd /opt 2>/dev/null || true; rm -rf '$CLONE_DIR' 2>/dev/null || true" EXIT
    git clone -b "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >/dev/null 2>&1
    cd "$CLONE_DIR"
    exec "$CLONE_DIR/remnasale-install.sh" --install "$CLONE_DIR" "$INSTALL_MODE"
else
    # Это повторный запуск из временной папки
    CLONE_DIR="$2"
    INSTALL_MODE="$3"
    if [ "$INSTALL_MODE" = "prod" ] || [ "$INSTALL_MODE" = "-p" ]; then
        INSTALL_MODE="prod"
    fi
fi

# Проверяем режим если скрипт вызван без аргументов --install
if [ "$1" != "--install" ] && [ "$1" != "--prod" ] && [ "$1" != "-p" ]; then
    check_mode "$1"
    exit $?
fi

if [ "$1" = "--prod" ] || [ "$1" = "-p" ]; then
    INSTALL_MODE="prod"
fi

# Очистка старых временных директорий (старше 1 часа)
find /tmp -maxdepth 1 -type d -name "tmp.*" -mmin +60 -exec rm -rf {} \; 2>/dev/null || true
# Очистка старых директорий сборки Docker
rm -rf /tmp/remnasale-build 2>/dev/null || true

# ═══════════════════════════════════════════════
# ФУНКЦИИ УСТАНОВКИ
# ═══════════════════════════════════════════════

generate_token() {
    openssl rand -hex 64 | tr -d '\n'
}

generate_password() {
    openssl rand -hex 32 | tr -d '\n'
}

generate_key() {
    openssl rand -base64 32 | tr -d '\n'
}

remove_from_caddy() {
    local caddy_dir="/opt/remnawave/caddy"
    local caddy_file="${caddy_dir}/Caddyfile"

    # Если Caddy нет — выходим
    [ -d "$caddy_dir" ] || return 0
    [ -f "$caddy_file" ] || return 0

    # Получаем домен из .env
    local app_domain=""
    if [ -f "$ENV_FILE" ]; then
        app_domain=$(grep "^APP_DOMAIN=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi

    # Если домен не найден, выходим
    [ -z "$app_domain" ] && return 0

    # Удаляем блок с доменом из Caddyfile используя sed
    # Ищем блок начинающийся с https://$app_domain { и заканчивающийся }
    sed -i "/^https:\/\/${app_domain}\s*{/,/^}/d" "$caddy_file" 2>/dev/null || true

    # Также удаляем пустые строки вокруг удаленного блока
    sed -i '/^$/N;/^\n$/d' "$caddy_file" 2>/dev/null || true

    # Перезапускаем Caddy (без затрагивания остальных сервисов)
    cd "$caddy_dir"
    docker compose restart caddy >/dev/null 2>&1 || true
}

configure_caddy() {
    local app_domain="$1"
    local caddy_dir="/opt/remnawave/caddy"
    local caddy_file="${caddy_dir}/Caddyfile"

    # Нет Caddy — тихо выходим
    [ -d "$caddy_dir" ] || return 0
    [ -f "$caddy_file" ] || return 0

    # Если домен уже есть — просто перезапускаем
    if ! grep -q -E "https://${app_domain}\s*\{" "$caddy_file"; then
        cat >> "$caddy_file" <<EOF

https://${app_domain} {
    reverse_proxy * http://remnasale:5000
}
EOF
    fi

    # Перезапуск Caddy (без затрагивания остальных сервисов)
    cd "$caddy_dir"
    docker compose restart caddy >/dev/null 2>&1 || true
}

remove_from_nginx() {
    local nginx_conf="/opt/remnawave/nginx.conf"
    local remnawave_dir="/opt/remnawave"

    # Если nginx.conf нет — выходим
    [ -f "$nginx_conf" ] || return 0

    # Собираем домены remnasale server-блоков ДО удаления (для очистки cert volumes)
    local -a remnasale_domains=()
    while IFS= read -r d; do
        [ -n "$d" ] && remnasale_domains+=("$d")
    done < <(awk '
        /^server \{/ { block = 1; buf = $0 "\n"; sn = ""; next }
        block && /server_name / { gsub(/;/, ""); for(i=1;i<=NF;i++) if($i!="server_name") sn = sn " " $i }
        block && /^\}/ {
            buf = buf $0 "\n"
            if (buf ~ /proxy_pass http:\/\/remnasale/) { gsub(/^ /, "", sn); print sn }
            block = 0; buf = ""; sn = ""
            next
        }
        block { buf = buf $0 "\n"; next }
    ' "$nginx_conf")

    # Удаляем upstream remnasale блок
    sed -i '/^upstream remnasale {$/,/^}$/d' "$nginx_conf" 2>/dev/null || true

    # Удаляем ВСЕ server-блоки, проксирующие на remnasale
    awk '
        /^server \{/ { block = 1; buf = $0 "\n"; next }
        block && /^\}/ {
            buf = buf $0 "\n"
            if (buf ~ /proxy_pass http:\/\/remnasale/) {
                block = 0; buf = ""; next
            }
            printf "%s", buf
            block = 0; buf = ""
            next
        }
        block { buf = buf $0 "\n"; next }
        !block { print }
    ' "$nginx_conf" > "${nginx_conf}.tmp" && mv "${nginx_conf}.tmp" "$nginx_conf"

    # Удаляем лишние пустые строки
    sed -i '/^$/N;/^\n$/d' "$nginx_conf" 2>/dev/null || true

    # Удаляем маппинг порта 5000 из docker-compose.yml бота
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        sed -i "/^      - '127.0.0.1:5000:5000'$/d" "$PROJECT_DIR/docker-compose.yml" 2>/dev/null || true
    fi

    # Удаляем volume-маунты сертификатов remnasale-доменов из remnawave docker-compose.yml
    local remnawave_compose="$remnawave_dir/docker-compose.yml"
    if [ -f "$remnawave_compose" ] && [ ${#remnasale_domains[@]} -gt 0 ]; then
        for domain in "${remnasale_domains[@]}"; do
            local cert_domain
            cert_domain=$(extract_cert_domain "$domain" 2>/dev/null || echo "$domain")
            sed -i "/${cert_domain//./\\.}/d" "$remnawave_compose" 2>/dev/null || true
        done
    fi

    # Сбрасываем WEBHOOK_ENABLED=false в .env бота
    if [ -f "$ENV_FILE" ]; then
        sed -i 's/^WEBHOOK_ENABLED=true$/WEBHOOK_ENABLED=false/' "$ENV_FILE" 2>/dev/null || true
    fi

    # Перезапускаем nginx
    cd "$remnawave_dir"
    docker compose restart remnawave-nginx >/dev/null 2>&1 || true
}

configure_nginx() {
    local app_domain="$1"
    local nginx_conf="/opt/remnawave/nginx.conf"
    local remnawave_dir="/opt/remnawave"
    local remnawave_compose="$remnawave_dir/docker-compose.yml"

    # Если nginx.conf нет — тихо выходим
    [ -f "$nginx_conf" ] || return 0

    # Определяем домен сертификата (может быть wildcard от базового домена)
    local cert_domain
    cert_domain=$(extract_cert_domain "$app_domain")

    # ── Автодетект типа nginx-конфигурации из существующих server блоков ──
    # Определяем: unix-сокет (xray) или прямой порт 443
    local listen_type="direct"  # по умолчанию — прямой порт
    if grep -q 'listen unix:/dev/shm/nginx.sock' "$nginx_conf" 2>/dev/null; then
        listen_type="unix_socket"
    fi

    # Определяем путь сертификатов из существующих блоков
    local cert_path_prefix="/etc/letsencrypt/live"
    local existing_cert_path
    existing_cert_path=$(grep -m1 'ssl_certificate "' "$nginx_conf" 2>/dev/null | sed 's/.*ssl_certificate "//;s|/fullchain\.pem.*||;s|/cert\.pem.*||')
    if [ -n "$existing_cert_path" ]; then
        # Извлекаем базовый путь (без домена) — например /etc/letsencrypt/live или /etc/nginx/ssl
        cert_path_prefix=$(echo "$existing_cert_path" | sed 's|/[^/]*$||')
    fi

    # ── Получаем SSL-сертификат если его нет ──
    if [ ! -d "/etc/letsencrypt/live/$cert_domain" ]; then
        # Проверяем наличие cloudflare.ini для DNS-01
        if [ -f "/etc/letsencrypt/cloudflare.ini" ]; then
            local base_domain
            base_domain=$(echo "$app_domain" | awk -F. '{print $(NF-1)"."$NF}')
            if [ ! -d "/etc/letsencrypt/live/$base_domain" ]; then
                (
                    certbot certonly --dns-cloudflare \
                        --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
                        --dns-cloudflare-propagation-seconds 30 \
                        -d "$base_domain" -d "*.$base_domain" \
                        --email "admin@$base_domain" --agree-tos --non-interactive \
                        --key-type ecdsa >/dev/null 2>&1
                ) &
                show_spinner "Получение wildcard сертификата для *.$base_domain"
                cert_domain="$base_domain"
            else
                cert_domain="$base_domain"
            fi
        else
            # Пробуем ACME HTTP-01
            (
                ufw allow 80/tcp >/dev/null 2>&1 || true
                certbot certonly --standalone \
                    -d "$app_domain" \
                    --email "admin@$app_domain" --agree-tos --non-interactive \
                    --http-01-port 80 \
                    --key-type ecdsa >/dev/null 2>&1
                ufw delete allow 80/tcp >/dev/null 2>&1 || true
                ufw reload >/dev/null 2>&1 || true
            ) &
            show_spinner "Получение сертификата для $app_domain"
            cert_domain="$app_domain"
        fi
    fi

    # ── Добавляем upstream если его нет ──
    if ! grep -q 'upstream remnasale {' "$nginx_conf"; then
        # Вставляем upstream после последнего существующего upstream блока (наверху файла)
        awk '
            /^upstream [a-zA-Z]/ { in_upstream=1 }
            in_upstream && /^\}/ { last_upstream_end=NR; in_upstream=0 }
            { lines[NR]=$0 }
            END {
                for (i=1; i<=NR; i++) {
                    print lines[i]
                    if (i == last_upstream_end) {
                        print ""
                        print "upstream remnasale {"
                        print "    server 127.0.0.1:5000;"
                        print "}"
                    }
                }
            }
        ' "$nginx_conf" > "${nginx_conf}.tmp" && mv "${nginx_conf}.tmp" "$nginx_conf"
    fi

    # ── Добавляем server блок если домена нет ──
    if ! grep -q "server_name ${app_domain};" "$nginx_conf"; then

        # Формируем listen-директивы и заголовки в зависимости от типа
        local listen_directives real_ip_header
        if [ "$listen_type" = "unix_socket" ]; then
            listen_directives="    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;\n    http2 on;"
            real_ip_header="\$proxy_protocol_addr"
        else
            listen_directives="    listen 443 ssl http2;\n    listen [::]:443 ssl http2;"
            real_ip_header="\$remote_addr"
        fi

        # Формируем пути сертификатов в зависимости от обнаруженного формата
        local ssl_cert_line ssl_key_line ssl_trusted_line
        ssl_cert_line="    ssl_certificate \"${cert_path_prefix}/${cert_domain}/fullchain.pem\";"
        ssl_key_line="    ssl_certificate_key \"${cert_path_prefix}/${cert_domain}/privkey.pem\";"
        ssl_trusted_line="    ssl_trusted_certificate \"${cert_path_prefix}/${cert_domain}/fullchain.pem\";"

        # Вставляем перед default_server блоком
        local server_block
        server_block=$(cat <<NGINXBLOCK

server {
    server_name ${app_domain};
$(echo -e "$listen_directives")

${ssl_cert_line}
${ssl_key_line}
${ssl_trusted_line}

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnasale;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP ${real_ip_header};
        proxy_set_header X-Forwarded-For ${real_ip_header};
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINXBLOCK
)
        # Вставляем перед блоком default_server
        awk -v block="$server_block" '
            /listen.*default_server/ && !inserted {
                # Ищем начало этого server блока (строка "server {")
                # Вставляем наш блок перед ним
            }
            /^server \{$/ { last_server_start = NR; last_server_buf = $0; buffering = 1; next }
            buffering {
                last_server_buf = last_server_buf "\n" $0
                if (/default_server/) {
                    print block
                    printf "%s\n", last_server_buf
                    buffering = 0
                    next
                }
                if (/^\}$/) {
                    printf "%s\n", last_server_buf
                    buffering = 0
                    next
                }
                next
            }
            { print }
        ' "$nginx_conf" > "${nginx_conf}.tmp" && mv "${nginx_conf}.tmp" "$nginx_conf"
    fi

    # ── Добавляем порт 5000 в docker-compose бота (для nginx host mode) ──
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        if ! grep -q "127.0.0.1:5000:5000" "$PROJECT_DIR/docker-compose.yml"; then
            # Ищем секцию remnasale и добавляем ports
            if grep -q 'ports:' "$PROJECT_DIR/docker-compose.yml" 2>/dev/null && \
               grep -A1 'ports:' "$PROJECT_DIR/docker-compose.yml" | grep -q '5000'; then
                : # Порт уже есть
            else
                # Добавляем ports после строки hostname: remnasale
                sed -i '/^    hostname: remnasale$/a\    ports:\n      - '\''127.0.0.1:5000:5000'\''' "$PROJECT_DIR/docker-compose.yml" 2>/dev/null || true
            fi
        fi
    fi

    # ── Добавляем volume сертификатов бота в remnawave docker-compose ──
    if [ -f "$remnawave_compose" ]; then
        # Если весь /etc/letsencrypt уже смонтирован — ничего не нужно
        if ! grep -q '/etc/letsencrypt:/etc/letsencrypt' "$remnawave_compose" 2>/dev/null; then
            # Проверяем, смонтирован ли уже конкретный сертификат
            if ! grep -q "/etc/letsencrypt/live/${cert_domain}/" "$remnawave_compose" 2>/dev/null; then
                # Для unix_socket монтируем в /etc/nginx/ssl/ (xray-сетап)
                # Для direct монтируем в /etc/letsencrypt/live/ (стандартный nginx)
                # Всегда монтируем в /etc/nginx/ssl/ — именно там nginx.conf ищет сертификаты
                sed -i "/nginx\.conf:\/etc\/nginx\/nginx\.conf:ro/a\\      - /etc/letsencrypt/live/${cert_domain}/fullchain.pem:/etc/nginx/ssl/${cert_domain}/fullchain.pem:ro\n      - /etc/letsencrypt/live/${cert_domain}/privkey.pem:/etc/nginx/ssl/${cert_domain}/privkey.pem:ro" "$remnawave_compose" 2>/dev/null || true
            fi
        fi
    fi

    # ── Перезапускаем nginx (без затрагивания остальных сервисов remnawave) ──
    (
        cd "$remnawave_dir"
        docker compose up -d --force-recreate remnawave-nginx >/dev/null 2>&1 || true
    ) &
    show_spinner "Перезапуск Nginx"
}

# Вспомогательная функция: определить домен сертификата
# (проверяет наличие wildcard или прямого сертификата)
extract_cert_domain() {
    local domain="$1"
    local base_domain
    base_domain=$(echo "$domain" | awk -F. '{print $(NF-1)"."$NF}')

    # Сначала проверяем прямой сертификат для конкретного домена
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        echo "$domain"
        return
    fi

    # Затем wildcard (базовый домен)
    if [ -d "/etc/letsencrypt/live/$base_domain" ]; then
        echo "$base_domain"
        return
    fi

    # По умолчанию — базовый домен (wildcard будет получен)
    echo "$base_domain"
}

# ═══════════════════════════════════════════════
# ПРОВЕРКИ ПРЕДУСЛОВИЙ
# ═══════════════════════════════════════════════

# Быстрые проверки ДО сбора данных
if ! command -v docker &> /dev/null; then
    print_error "Docker не установлен!"
    exit 1
fi
if ! command -v openssl &> /dev/null; then
    print_error "OpenSSL не установлен!"
    exit 1
fi

# Автоопределение реверс-прокси (до сбора данных — влияет на webhook)
if [ -d "/opt/remnawave/caddy" ]; then
    REVERSE_PROXY="caddy"
elif [ -f "/opt/remnawave/nginx.conf" ]; then
    REVERSE_PROXY="nginx"
else
    REVERSE_PROXY="none"
fi

# ═══════════════════════════════════════════════
# СБОР ДАННЫХ ДЛЯ УСТАНОВКИ
# ═══════════════════════════════════════════════

clear
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${GREEN}       🚀 УСТАНОВКА REMNASALE${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo
echo -e "${DARKGRAY}Введите данные для установки бота${NC}"
echo
echo -e "${BLUE}──────────────────────────────────────${NC}"
echo

# APP_DOMAIN
while true; do
    printf '\033[s'  # сохраняем позицию курсора перед промптом
    reading_inline "Введите домен бота (напр. bot.example.com):" APP_DOMAIN
    if [ -z "$APP_DOMAIN" ]; then
        print_error "Домен не может быть пустым!"
        exit 1
    fi
    if check_domain "$APP_DOMAIN"; then
        break
    fi
    echo
    echo -e "${DARKGRAY}Нажмите Enter чтобы ввести другой домен, или Esc для выхода.${NC}"
    key=""
    while true; do
        read -s -n 1 key
        if [[ "$key" == $'\x1b' ]]; then
            echo
            exit 1
        elif [[ "$key" == "" ]]; then
            break
        fi
    done
    printf '\033[u\033[J'  # возвращаемся к сохранённой позиции и очищаем всё ниже
done

# APP_WEB_DOMAIN
reading_inline "Введите домен веб-сайта (Enter = пропустить, настроите позже):" APP_WEB_DOMAIN
if [ -z "$APP_WEB_DOMAIN" ]; then
    APP_WEB_DOMAIN=""
fi

# BOT_TOKEN
reading_inline "Введите Токен телеграм бота:" BOT_TOKEN
if [ -z "$BOT_TOKEN" ]; then
    print_error "BOT_TOKEN не может быть пустым!"
    exit 1
fi

# BOT_DEV_ID
reading_inline "Введите телеграм ID разработчика:" BOT_DEV_ID
if [ -z "$BOT_DEV_ID" ]; then
    print_error "BOT_DEV_ID не может быть пустым!"
    exit 1
fi

# BOT_SUPPORT_USERNAME
reading_inline "Введите username группы поддержки (без @, Enter = ID разработчика):" BOT_SUPPORT_USERNAME
if [ -z "$BOT_SUPPORT_USERNAME" ]; then
    BOT_SUPPORT_USERNAME="$BOT_DEV_ID"
fi

# REMNAWAVE_TOKEN
reading_inline "Введите API Токен Remnawave:" REMNAWAVE_TOKEN
if [ -z "$REMNAWAVE_TOKEN" ]; then
    print_error "REMNAWAVE_TOKEN не может быть пустым!"
    exit 1
fi

# ═══════════════════════════════════════════════
# ПРОЦЕСС УСТАНОВКИ
# ═══════════════════════════════════════════════

clear
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${GREEN}       🚀 ПРОЦЕСС УСТАНОВКИ${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo

# Отмечаем, что установка началась - теперь при ошибке нужно очищать
INSTALL_STARTED=true

(
  # Docker log rotation: создаём daemon.json если нет
  if [ ! -f /etc/docker/daemon.json ]; then
      cat > /etc/docker/daemon.json <<'DJSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DJSON
  fi
) &
show_spinner "Настройка системы"

# 2. Подготовка целевой директории
(
  # Создаем целевую директорию
  mkdir -p "$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR/logs"
  mkdir -p "$PROJECT_DIR/backups"
  mkdir -p "$PROJECT_DIR/assets"
  chmod 755 "$PROJECT_DIR/logs" "$PROJECT_DIR/backups" "$PROJECT_DIR/assets"

  # Создаем сеть Docker если не существует
  if ! docker network ls | grep -q "remnawave-network"; then
      docker network create remnawave-network 2>/dev/null || true
  fi
) &
show_spinner "Подготовка целевой директории"

# 3. Определение, откуда копировать файлы
# Если скрипт запущен не из целевой директории, значит мы в клонированной папке
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SOURCE_DIR="$SCRIPT_DIR"

if [ "$SOURCE_DIR" = "/opt/remnasale" ]; then
    # Скрипт уже в целевой директории - ничего не копируем
    COPY_FILES=false
else
    # Скрипт в клонированной папке - копируем только конфигурационные файлы
    COPY_FILES=true
    # Только конфигурационные файлы - БЕЗ исходников (src, scripts останутся во временной папке)
    SOURCE_FILES=(
        "docker-compose.yml"
    )
fi

# 4. Копирование конфигурационных файлов если нужно
if [ "$COPY_FILES" = true ]; then
    (
      # Копируем только конфигурационные файлы
      for file in "${SOURCE_FILES[@]}"; do
          if [ -f "$SOURCE_DIR/$file" ]; then
              cp "$SOURCE_DIR/$file" "$PROJECT_DIR/"
          fi
      done
      
      # Копируем только assets (для кастомизации баннеров пользователем)
      if [ -d "$SOURCE_DIR/assets" ]; then
          rm -rf "$PROJECT_DIR/assets" 2>/dev/null || true
          cp -r "$SOURCE_DIR/assets" "$PROJECT_DIR/"
      fi
      
      # Копируем version в корень бота
      if [ -f "$SOURCE_DIR/version" ]; then
          cp "$SOURCE_DIR/version" "$PROJECT_DIR/version"
      fi

      # Копируем remnasale-install.sh в системную папку (не в корень бота)
      sudo mkdir -p "$SYSTEM_INSTALL_DIR"
      _src="$(realpath "$SOURCE_DIR/remnasale-install.sh" 2>/dev/null || echo "$SOURCE_DIR/remnasale-install.sh")"
      _dst="$(realpath "$SYSTEM_INSTALL_DIR/remnasale-install.sh" 2>/dev/null || echo "$SYSTEM_INSTALL_DIR/remnasale-install.sh")"
      if [ "$_src" != "$_dst" ]; then
          sudo cp "$SOURCE_DIR/remnasale-install.sh" "$SYSTEM_INSTALL_DIR/remnasale-install.sh"
      fi
      sudo chmod +x "$SYSTEM_INSTALL_DIR/remnasale-install.sh"
    )
    wait  # Ждем завершения копирования без спиннера
fi

# 5. Создание .env файла
if [ ! -f "$ENV_FILE" ]; then
    if [ ! -f "$SOURCE_DIR/.env.example" ]; then
        print_error "Файл .env.example не найден в исходной директории!"
        print_error "Возможно предыдущая установка была прервана. Запустите установку заново."
        # Очистка остатков прерванной установки
        sudo rm -rf "$SYSTEM_INSTALL_DIR" 2>/dev/null || true
        exit 1
    fi
    (
      cp "$SOURCE_DIR/.env.example" "$ENV_FILE"
    ) &
    show_spinner "Инициализация конфигурации"
else
    print_success "Конфигурация уже существует"
fi

# 6. Определение реверс-прокси (уже определено до сбора данных)
if [ "$REVERSE_PROXY" = "caddy" ]; then
    print_success "Обнаружен реверс прокси Caddy"
elif [ "$REVERSE_PROXY" = "nginx" ]; then
    print_success "Обнаружен реверс прокси Nginx"
else
    print_success "Реверс-прокси не обнаружен"
fi

# 7. Записываем собранные данные в .env
(
  update_env_var "$ENV_FILE" "APP_DOMAIN" "$APP_DOMAIN"
  update_env_var "$ENV_FILE" "BOT_MINI_APP" "https://${APP_DOMAIN}/web/miniapp"
  update_env_var "$ENV_FILE" "APP_WEB_DOMAIN" "$APP_WEB_DOMAIN"
  update_env_var "$ENV_FILE" "BOT_TOKEN" "$BOT_TOKEN"
  update_env_var "$ENV_FILE" "BOT_DEV_ID" "$BOT_DEV_ID"
  update_env_var "$ENV_FILE" "BOT_SUPPORT_USERNAME" "$BOT_SUPPORT_USERNAME"
  update_env_var "$ENV_FILE" "REMNAWAVE_TOKEN" "$REMNAWAVE_TOKEN"
) &
show_spinner "Сохранение конфигурации"

# 1. СНАЧАЛА - Создание конфигурации (в фоне со спинером)
(
  # Автогенерация ключей безопасности
  if grep -q "^APP_CRYPT_KEY=$" "$ENV_FILE"; then
    APP_CRYPT_KEY=$(openssl rand -base64 32 | tr -d '\n')
    update_env_var "$ENV_FILE" "APP_CRYPT_KEY" "$APP_CRYPT_KEY"
  fi

  if grep -q "^BOT_SECRET_TOKEN=$" "$ENV_FILE"; then
    BOT_SECRET_TOKEN=$(openssl rand -hex 64 | tr -d '\n')
    update_env_var "$ENV_FILE" "BOT_SECRET_TOKEN" "$BOT_SECRET_TOKEN"
  fi

  # Генерация пароля БД
  if grep -q "^DATABASE_PASSWORD=" "$ENV_FILE"; then
    CURRENT_DB_PASS=$(grep "^DATABASE_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$CURRENT_DB_PASS" ]; then
      DATABASE_PASSWORD=$(openssl rand -hex 32 | tr -d '\n')
      update_env_var "$ENV_FILE" "DATABASE_PASSWORD" "$DATABASE_PASSWORD"
    else
      DATABASE_PASSWORD="$CURRENT_DB_PASS"
    fi
  else
    DATABASE_PASSWORD=$(openssl rand -hex 32 | tr -d '\n')
    echo "DATABASE_PASSWORD=$DATABASE_PASSWORD" >> "$ENV_FILE"
  fi

  # Синхронизируем DATABASE_USER с POSTGRES_USER
  DATABASE_USER=$(grep "^DATABASE_USER=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
  if [ -n "$DATABASE_USER" ]; then
    if grep -q "^POSTGRES_USER=" "$ENV_FILE"; then
      update_env_var "$ENV_FILE" "POSTGRES_USER" "$DATABASE_USER"
    else
      echo "POSTGRES_USER=$DATABASE_USER" >> "$ENV_FILE"
    fi
  fi

  # Синхронизируем DATABASE_PASSWORD с POSTGRES_PASSWORD
  if grep -q "^POSTGRES_PASSWORD=" "$ENV_FILE"; then
    update_env_var "$ENV_FILE" "POSTGRES_PASSWORD" "$DATABASE_PASSWORD"
  else
    echo "POSTGRES_PASSWORD=$DATABASE_PASSWORD" >> "$ENV_FILE"
  fi

  # Синхронизируем DATABASE_NAME с POSTGRES_DB
  DATABASE_NAME=$(grep "^DATABASE_NAME=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
  if [ -n "$DATABASE_NAME" ]; then
    if grep -q "^POSTGRES_DB=" "$ENV_FILE"; then
      update_env_var "$ENV_FILE" "POSTGRES_DB" "$DATABASE_NAME"
    else
      echo "POSTGRES_DB=$DATABASE_NAME" >> "$ENV_FILE"
    fi
  fi

  # Исправляем DATABASE_HOST и REDIS_HOST на актуальные имена контейнеров
  if grep -q "^DATABASE_HOST=" "$ENV_FILE"; then
    update_env_var "$ENV_FILE" "DATABASE_HOST" "remnasale-db"
  else
    echo "DATABASE_HOST=remnasale-db" >> "$ENV_FILE"
  fi
  if grep -q "^REDIS_HOST=" "$ENV_FILE"; then
    update_env_var "$ENV_FILE" "REDIS_HOST" "remnasale-redis"
  else
    echo "REDIS_HOST=remnasale-redis" >> "$ENV_FILE"
  fi

  # Генерация пароля Redis
  if grep -q "^REDIS_PASSWORD=$" "$ENV_FILE"; then
    CURRENT_REDIS_PASS=$(grep "^REDIS_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$CURRENT_REDIS_PASS" ]; then
      REDIS_PASSWORD=$(openssl rand -hex 32 | tr -d '\n')
      update_env_var "$ENV_FILE" "REDIS_PASSWORD" "$REDIS_PASSWORD"
    fi
  fi

  if grep -q "^REMNAWAVE_WEBHOOK_SECRET=" "$ENV_FILE"; then
    CURRENT_WEBHOOK_SECRET=$(grep "^REMNAWAVE_WEBHOOK_SECRET=" "$ENV_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$CURRENT_WEBHOOK_SECRET" ]; then
      REMNAWAVE_WEBHOOK_SECRET=$(openssl rand -hex 32 | tr -d '\n')
      update_env_var "$ENV_FILE" "REMNAWAVE_WEBHOOK_SECRET" "$REMNAWAVE_WEBHOOK_SECRET"
    fi
  fi
) &
show_spinner "Создание конфигурации"

# 2. Синхронизация webhook (в фоне со спинером)
(
  REMNAWAVE_ENV="/opt/remnawave/.env"

  if [ -f "$REMNAWAVE_ENV" ]; then
    # Включаем webhook
    if grep -q "^WEBHOOK_ENABLED=" "$REMNAWAVE_ENV"; then
      sed -i "s|^WEBHOOK_ENABLED=.*|WEBHOOK_ENABLED=true|" "$REMNAWAVE_ENV"
    else
      echo "WEBHOOK_ENABLED=true" >> "$REMNAWAVE_ENV"
    fi

    # Копируем WEBHOOK_SECRET_HEADER
    REMNAWAVE_SECRET=$(grep "^WEBHOOK_SECRET_HEADER=" "$REMNAWAVE_ENV" | cut -d'=' -f2)
    if [ -n "$REMNAWAVE_SECRET" ]; then
      update_env_var "$ENV_FILE" "REMNAWAVE_WEBHOOK_SECRET" "$REMNAWAVE_SECRET"
    fi

    # Подставляем домен
    if [ -n "$APP_DOMAIN" ]; then
      if grep -q "^WEBHOOK_URL=" "$REMNAWAVE_ENV"; then
        sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://${APP_DOMAIN}/api/v1/remnawave|" "$REMNAWAVE_ENV"
      else
        echo "WEBHOOK_URL=https://${APP_DOMAIN}/api/v1/remnawave" >> "$REMNAWAVE_ENV"
      fi
    fi

    # Перезапускаем remnawave для применения новых webhook-настроек
    cd /opt/remnawave && docker compose up -d --force-recreate remnawave >/dev/null 2>&1 || true
  fi
) &
show_spinner "Синхронизация с Remnawave"

# 3. Создание структуры папок (в фоне со спинером)
(
  mkdir -p "$PROJECT_DIR"/{assets,backups,logs}
) &
show_spinner "Создание структуры папок"

# 4. Удаление старых томов БД для свежей установки (в фоне со спинером)
(
  cd "$PROJECT_DIR"
  # Останавливаем контейнеры если они есть
  docker compose down >/dev/null 2>&1 || true
  # Удаляем том БД чтобы PostgreSQL переинициализировалась с правильными паролями
  docker volume rm remnasale-db-data >/dev/null 2>&1 || true
) &
show_spinner "Очистка старых данных БД"

# 5. Сборка Docker образа из временной папки (в фоне со спинером)
(
  # Собираем образ из SOURCE_DIR (временная папка с исходниками)
  if [ "$COPY_FILES" = true ] && [ -d "$SOURCE_DIR" ]; then
    cd "$SOURCE_DIR"
    docker build -t remnasale:local \
      --build-arg BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --build-arg BUILD_BRANCH="$REPO_BRANCH" \
      --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
      --build-arg BUILD_TAG="$(grep '^version:' version 2>/dev/null | cut -d: -f2 | tr -d ' \n' || echo 'unknown')" \
      . >/dev/null 2>&1
  fi
) &
show_spinner "Сборка Docker образа"

# 6. Настройка реверс-прокси ПЕРЕД запуском бота
#    (бот при старте сразу проверяет webhook — nginx должен быть готов)
if [ "$REVERSE_PROXY" = "caddy" ]; then
  (
    configure_caddy "$APP_DOMAIN"
    # Add web domain to Caddy if different from bot domain
    if [ -n "$APP_WEB_DOMAIN" ] && [ "$APP_WEB_DOMAIN" != "$APP_DOMAIN" ]; then
        configure_caddy "$APP_WEB_DOMAIN"
    fi
  ) &
  show_spinner "Настройка и перезапуск Caddy"
elif [ "$REVERSE_PROXY" = "nginx" ]; then
  configure_nginx "$APP_DOMAIN"
  # Add web domain to Nginx if different from bot domain
  if [ -n "$APP_WEB_DOMAIN" ] && [ "$APP_WEB_DOMAIN" != "$APP_DOMAIN" ]; then
      configure_nginx "$APP_WEB_DOMAIN"
  fi
fi

# 7. Запуск контейнеров и ожидание запуска бота
cd "$PROJECT_DIR"
docker compose up -d >/dev/null 2>&1

echo
show_spinner_until_log "remnasale" "Digital.*Freedom.*Core" "Запуск бота" 90 && BOT_START_RESULT=0 || BOT_START_RESULT=$?
echo

# ═══════════════════════════════════════════════
# ЗАВЕРШЕНИЕ УСТАНОВКИ
# ═══════════════════════════════════════════════

if [ ${BOT_START_RESULT:-1} -eq 0 ]; then
    clear
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo -e "${GREEN}    🎉 УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!${NC}"
    echo -e "${BLUE}══════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}✅ Бот успешно установлен и запущен${NC}"
    echo
    echo -e "${BLUE}──────────────────────────────────────${NC}"
    echo
    echo -e "${WHITE}✅ Команда вызова меню бота:${NC} ${YELLOW}remnasale${NC} или ${YELLOW}rs${NC}"
    echo
    echo -e "${BLUE}══════════════════════════════════════${NC}"
elif [ ${BOT_START_RESULT:-1} -eq 2 ]; then
    while true; do
        MENU_ESC_LABEL="Выход"
        show_arrow_menu "❌ Ошибка при запуске бота" \
            "📜 Показать лог запуска" \
            "──────────────────────────────────────" \
            "❌ Выйти из программы установки"
        error_choice=$?
        case $error_choice in
            0)  # Показать логи
                clear
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${RED}ЛОГИ ОШИБОК:${NC}"
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                docker compose -f "$PROJECT_DIR/docker-compose.yml" logs --tail 50 remnasale
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                continue
                ;;
            2|255)  # Выход / Esc
                break
                ;;
        esac
    done
else
    while true; do
        MENU_ESC_LABEL="Выход"
        show_arrow_menu "⚠️  Запуск бота не был произведен\n       за отведенное время" \
            "📜 Показать лог запуска" \
            "──────────────────────────────────────" \
            "❌ Выйти из программы установки"
        timeout_choice=$?
        case $timeout_choice in
            0)  # Показать логи
                clear
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo -e "${WHITE}ЛОГИ БОТА:${NC}"
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                docker compose -f "$PROJECT_DIR/docker-compose.yml" logs --tail 50 remnasale
                echo -e "${BLUE}══════════════════════════════════════${NC}"
                echo
                echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}"
                read -p ""
                continue
                ;;
            2|255)  # Выход / Esc
                break
                ;;
        esac
    done
fi
echo

# Отмечаем успешное завершение установки
INSTALL_STARTED=false
INSTALL_COMPLETED=true

# Создание глобальной команды remnasale
(
    sudo mkdir -p /usr/local/lib/remnasale
    # Копируем remnasale-install.sh в системную папку (до удаления SOURCE_DIR)
    _src="$(realpath "$SOURCE_DIR/remnasale-install.sh" 2>/dev/null || echo "$SOURCE_DIR/remnasale-install.sh")"
    _dst="$(realpath "/usr/local/lib/remnasale/remnasale-install.sh" 2>/dev/null || echo "/usr/local/lib/remnasale/remnasale-install.sh")"
    if [ "$_src" != "$_dst" ] && [ -f "$SOURCE_DIR/remnasale-install.sh" ]; then
        sudo cp "$SOURCE_DIR/remnasale-install.sh" /usr/local/lib/remnasale/remnasale-install.sh
    fi
    sudo chmod +x /usr/local/lib/remnasale/remnasale-install.sh

    sudo tee /usr/local/bin/remnasale > /dev/null << 'EOF'
#!/bin/bash
# Запускаем remnasale-install.sh из системной папки
if [ -f "/usr/local/lib/remnasale/remnasale-install.sh" ]; then
    exec /usr/local/lib/remnasale/remnasale-install.sh
else
    echo "❌ remnasale-install.sh не найден. Переустановите бота."
    exit 1
fi
EOF
    sudo chmod +x /usr/local/bin/remnasale
    sudo ln -sf /usr/local/bin/remnasale /usr/local/bin/rs
) >/dev/null 2>&1

# Удаление исходной папки если она не в /opt/remnasale (после копирования в системную папку)
if [ "$COPY_FILES" = true ] && [ "$SOURCE_DIR" != "/opt/remnasale" ] && [ "$SOURCE_DIR" != "/" ]; then
    cd /opt
    rm -rf "$SOURCE_DIR" 2>/dev/null || true
fi

# Ожидание ввода перед возвратом в главное меню
echo
printf "\033[?25l${DARKGRAY}${BLUE}Enter${DARKGRAY}: Продолжить${NC}\n"
read -rs -n1 2>/dev/null
printf "\033[?25h"
clear

cd /opt

# Удаляем временную папку клонирования если она была создана
if [ -n "$CLONE_DIR" ] && [ -d "$CLONE_DIR" ]; then
    rm -rf "$CLONE_DIR" 2>/dev/null || true
fi

# Возвращаемся в главное меню
show_full_menu
