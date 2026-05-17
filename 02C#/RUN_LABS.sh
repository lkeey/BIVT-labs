#!/bin/bash

# ====================================
# ЗАПУСК ЛАБОРАТОРНЫХ РАБОТ 5–9
# ====================================

echo "Выберите лабораторную работу для запуска:"
echo ""
echo "5 - Lab 5: GeometryGUI (Геометрические фигуры, ООП)"
echo "6 - Lab 6: TaskManager (Делегаты и события)"
echo "7 - Lab 7: TicTacToe (Крестики-нолики 10×10)"
echo "8 - Lab 8: RssReaderApp (RSS + MySQL)"
echo "9 - Lab 9: AdsBoardApp (UDP multicast — доска объявлений)"
echo ""
read -p "Введите номер лабы: " lab_num

case $lab_num in
  5)
    echo "🚀 Запуск Lab 5: GeometryGUI..."
    cd "lab05/GeometryGUI" || exit
    dotnet build
    dotnet run
    ;;
  6)
    echo "🚀 Запуск Lab 6: TaskManager..."
    cd "lab06/TaskManagerGUI" || exit
    dotnet build
    dotnet run
    ;;
  7)
    echo "🚀 Запуск Lab 7: TicTacToe..."
    cd "lab07/TicTacToe" || exit
    dotnet build
    dotnet run
    ;;
  8)
    echo "🚀 Запуск Lab 8: RssReaderApp..."
    cd "lab08/RssReaderApp" || exit
    dotnet build
    dotnet run
    ;;
  9)
    echo "🚀 Запуск Lab 9: AdsBoardApp..."
    cd "lab09/AdsBoardApp" || exit
    dotnet build
    dotnet run
    ;;
  *)
    echo "❌ Неверный номер лабы!"
    exit 1
    ;;
esac
