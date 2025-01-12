#!/bin/bash

# -------------------------
# Changelog:
# cw10 - 11.01.2025
# Author: Szymon Marczak
# -------------------------

# Deklaracja parametrów
NUMERINDEKSU="405302"
TIMESTAMP=$(date +%m%d%Y)
LOGFILE="C:/Users/Szymon Marczak/Desktop/semestr 2/BDP/zadanie_bash_Szymon_Marczak${TIMESTAMP}.log"
FILE_URL="http://home.agh.edu.pl/~wsarlej/dyd/bdp2/materialy/cw10/InternetSales_new.zip"
ARCHIVE_PASSWORD="bdp2agh"
DB_HOST="localhost"
DB_USER="postgres"
DB_PASSWORD="MzQyNg=="
DB_NAME="cw10"
TABLE_NAME="customers_${NUMERINDEKSU}"

# Dekodowanie hasła
DB_PASSWORD=$(echo $DB_PASSWORD | base64 --decode)

# Funkcja logująca
log() {
  echo "$(date +%Y%m%d%H%M%S) - $1 - $2" >> "$LOGFILE"
}

# Krok a - pobieranie pliku
log "Pobieranie pliku" "Start"

curl -L "$FILE_URL" -o downloaded_file.zip

log "Pobieranie pliku" "Zakończenie"

# Krok b - rozpakowanie pliku zip

log "Rozpakowwywanie pliku" "Start"

unzip -o -P "$ARCHIVE_PASSWORD" downloaded_file.zip

log "Rozpakowwywanie pliku" "Zakończenie"

# Krok c - walidacja i przetwarzanie pliku txt 
log "Walidacja" "Start"

INPUT_FILE="InternetSales_new.txt"
OUTPUT_FILE="InternetSales_validated.csv"
BAD_FILE="InternetSales_new.bad_${TIMESTAMP}"
 
# Funkcja walidująca plik
validate_file() {

    HEADER=$(head -n 1 "$INPUT_FILE")
    COLUMN_COUNT=$(echo "$HEADER" | awk -F'|' '{print NF}')
 
    mapfile -t LINES < <(tail -n +2 "$INPUT_FILE")
    for LINE in "${LINES[@]}"; do
        # Puste linie do pominięcia
        if [[ -z "$LINE" ]]; then
            continue
        fi
 
        # Sprawdzanie liczby kolumn
        LINE_COLUMN_COUNT=$(echo "$LINE" | awk -F'|' '{print NF}')
        if [[ "$LINE_COLUMN_COUNT" -ne "$COLUMN_COUNT" ]]; then
            echo "$LINE" >> "$BAD_FILE"
            continue
        fi
 
        # Rozdzielenie kolumn i walidacja wartości
        IFS='|' read -r ProductKey CurrencyAlternateKey Customer_Name OrderDateKey OrderQuantity UnitPrice SecretCode <<< "$LINE"
 
        # Sprawdzenie OrderQuantity
        if [[ "$OrderQuantity" -gt 100 ]]; then
            echo "$LINE" >> "$BAD_FILE"
            continue
        fi
 
        # Usuwamy SecretCode przed przesyłem do .bad
        SecretCode=""
 
        # Walidacja Customer_Name i dzielenie na FIRST_NAME i LAST_NAME 
        if [[ "$Customer_Name" == *","* ]]; then
            LAST_NAME=${Customer_Name%%,*}  # Wszystko przed przecinkiem
            FIRST_NAME=${Customer_Name#*,} # Wszystko po przecinku
 
            LAST_NAME=$(echo "$LAST_NAME" | tr -d '"')
            FIRST_NAME=$(echo "$FIRST_NAME" | tr -d '"')
        else
            echo "$LINE" >> "$BAD_FILE"
            continue
        fi
 
        # Tworzenie nowej lini z rozdzielonym Customer_Name
        VALID_LINE="$ProductKey|$CurrencyAlternateKey|$LAST_NAME|$FIRST_NAME|$OrderDateKey|$OrderQuantity|$UnitPrice"
        echo "$VALID_LINE" >> "$OUTPUT_FILE"
    done
}
 
> "$OUTPUT_FILE"
> "$BAD_FILE"
 
# nagłówek
HEADER_NEW=$(echo "$HEADER" | sed 's/Customer_Name/LAST_NAME|FIRST_NAME/')
echo "$HEADER_NEW" > "$OUTPUT_FILE"
 
# Wywołanie funkcji walidacji
validate_file
 
# Usunięcie duplikatów z wyniku końcowego
sort "$OUTPUT_FILE" | uniq > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
 
log "Walidacja zakończona. Plik wynikowy: $OUTPUT_FILE, Plik z błędami: $BAD_FILE"





# Krok d: Tworzenie tabeli w bazie danych PostgreSQL
log "Tworzenie bazy" "Start"

# Sprawdzenie, czy tabela istnieje
TABLE_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '$TABLE_NAME');" | tr -d '[:space:]')

if [[ "$TABLE_EXISTS" == 't' ]]; then
  # Jeśli tabela istnieje, zerujemy jej zawartość
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "TRUNCATE TABLE $TABLE_NAME;"
  if [[ $? -eq 0 ]]; then
    log "Tworzenie bazy" "Czyszczenie tabeli jeśli istnieją rekordy"
  else
    log "Tworzenie bazy" "Tabele pusta"
    exit 1
  fi
else
  # Jeśli tabela nie istnieje, tworzymy ją
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
  CREATE TABLE $TABLE_NAME (
    ProductKey int,
    CurrencyAlternateKey VARCHAR(20),
    LAST_NAME VARCHAR(100),
    FIRST_NAME VARCHAR(100),
    OrderDateKey varchar(100),
    OrderQuantity INT,
    UnitPrice varchar(100),
    SecretCode VARCHAR(10)
  );"
  
  if [[ $? -eq 0 ]]; then
    log "Tworzenie bazy" "Pomyślne utworzenie bazy"
  else
    log "Tworzenie bazy" "Nieudane utworzenie bazy"
    exit 1
  fi
fi

# Krok e - załadowanie danych do PostgresSQL
log "Ładowanie danych" "Start"

PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "\COPY $TABLE_NAME(ProductKey, CurrencyAlternateKey, LAST_NAME, FIRST_NAME,OrderDateKey, OrderQuantity, UnitPrice) FROM '$OUTPUT_FILE' DELIMITER '|' CSV HEADER;"
if [[ $? -eq 0 ]]; then
  log "Ładowanie danych" "Pomyślnie"
else
  log "Ładowanie danych" "Nieudane"
  exit 1
fi

# Krok f - archwizacja pliku
log "Archiwizacja" "Start"

PROCESSED_DIR="PROCESSED"

if [ ! -d "$PROCESSED_DIR" ]; then
  mkdir -p "$PROCESSED_DIR"
  log "Archiwizacja" "PROCESSED - pomyślnie utworzono folder"
else
  log "Archiwizacja" "PROCESSED -folder już istnieje"
fi

mv "$OUTPUT_FILE" "$PROCESSED_DIR/${TIMESTAMP}_$OUTPUT_FILE"
if [ $? -eq 0 ]; then
  log "Archiwizacja" "Pomyślnie"
else
  log "Archiwizacja" "Nieudane"
  exit 1
fi

# Krok g - aktulizacja SecretCode
log "Aktulizacja SecretCode" "Start"

PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
UPDATE $TABLE_NAME SET SecretCode = substring(md5(random()::text), 1, 10);
"
if [[ $? -eq 0 ]]; then
  log "Aktulizacja SecretCode" "Pomyślnie"
else
  log "Aktulizacja SecretCode" "Nieudane"
  exit 1
fi

# Krok h - eksport tabeli do csv
EXPORT_FILE="${TABLE_NAME}.csv"
log "Export" "Start"
PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "\COPY (SELECT * FROM $TABLE_NAME) TO '$EXPORT_FILE' DELIMITER ';' CSV;"
if [[ -f "$EXPORT_FILE" ]]; then
  mv "$EXPORT_FILE" "$PROCESSED_DIR/$EXPORT_FILE"
  log "Export" "Pomyślnie"
else
  log "Export" "Nieudane - plik nie został stworzony"
  exit 1
fi

# Step i - Kompresja wyeksportowanego pliku
log "Kompresja" "Start"
if tar -czf "$PROCESSED_DIR/${EXPORT_FILE}.tar.gz" -C "$PROCESSED_DIR" "$EXPORT_FILE"; then
  log "Kompresja" "Pomyślnie"
else
  log "Kompresja" "Nieudane"
  exit 1
fi

# Czyszczenie
if [[ -f "$PROCESSED_DIR/$EXPORT_FILE" ]]; then
  rm "$PROCESSED_DIR/$EXPORT_FILE"
  log "Czyszczenie" "Plik usunięty pomyślnie"
else
  log "Czyszczenie" "Brak pliku do usunięcia"
fi

# Log końcowy
log "Wykonanie skryptu" "Skrypt zakończony pomyślnie"

# przeniesienie loga do PROCEED
mv "$LOGFILE" "$PROCESSED_DIR/"