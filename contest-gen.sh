#!/bin/bash
# contest-gen.sh - генерирует папку для контеста с файлами задач
# Использование: ./contest-gen.sh 1920 5
#   где 1920 - номер контеста, 5 - количество задач (A-E)

CONTEST_NUM=$1
NUM_PROBLEMS=$2

if [ -z "$CONTEST_NUM" ] || [ -z "$NUM_PROBLEMS" ]; then
    echo "Usage: $0 <contest_number> <num_problems>"
    echo "Example: $0 1920 5  # создаст задачи A-E для контеста 1920"
    exit 1
fi

if ! [[ "$NUM_PROBLEMS" =~ ^[0-9]+$ ]] || [ "$NUM_PROBLEMS" -lt 1 ] || [ "$NUM_PROBLEMS" -gt 26 ]; then
    echo "❌ Number of problems must be between 1 and 26"
    exit 1
fi

CONTEST_DIR="contests/${CONTEST_NUM}"

# Создаем директорию для контеста
mkdir -p "$CONTEST_DIR"
echo "📁 Created directory: $CONTEST_DIR"

# Шаблон для C++ решения
read -r -d '' CPP_TEMPLATE << 'EOF'
#include <bits/stdc++.h>
using namespace std;

#define ll long long
#define ld long double
#define pb push_back
#define all(x) (x).begin(), (x).end()
#define sz(x) (int)(x).size()
using itn = int;

void solve() {
    // TODO: implement solution
}

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 1;
    cin >> t;
    while (t--) {
        solve();
    }

    return 0;
}
EOF

# Генерируем файлы для задач
for ((i=0; i<NUM_PROBLEMS; i++)); do
    LETTER=$(printf "\\$(printf '%03o' $((65 + i)))")
    PROBLEM="${CONTEST_NUM}${LETTER}"
    FILE="${CONTEST_DIR}/${PROBLEM}.cpp"

    echo "$CPP_TEMPLATE" > "$FILE"
    echo "✅ Created: $FILE"
done

# Копируем run.sh в папку контеста
if [ -f "run.sh" ]; then
    cp run.sh "$CONTEST_DIR/"
    echo "✅ Copied run.sh to $CONTEST_DIR/"
fi

echo ""
echo "🎉 Contest $CONTEST_NUM ready with $NUM_PROBLEMS problems!"
echo "📂 Location: $CONTEST_DIR"
echo ""
echo "Usage:"
echo "  cd $CONTEST_DIR"
echo "  ./run.sh ${CONTEST_NUM}A"
