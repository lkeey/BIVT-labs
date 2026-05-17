# ОТЧЕТ ПО ЛАБОРАТОРНОЙ РАБОТЕ №7

---

## 2. ЗАДАНИЕ НА ЛАБОРАТОРНУЮ РАБОТУ

В рамках лабораторной работы были решены следующие задачи:

**Уровень 2 (+4 балла):**
1. Реализовать игру "Крестики-нолики" на поле 10×10
2. Условие победы: 5 символов в ряд (горизонталь, вертикаль, диагонали)
3. Реализовать игру человек vs человек
4. Вести счет игроков
5. Хранить состояние в двумерном массиве `int[10,10]`
6. Определять исход: победа игрока 1, победа игрока 2, ничья
7. Выводить MessageBox с результатом раунда
8. Отображать выигрышную комбинацию линией
9. Добавить кнопки "Новая игра" и "Сбросить счет"
10. Разработать графический интерфейс на Avalonia UI (адаптация Windows Forms для macOS)

---

## 5. ЛИСТИНГ ПРОГРАММЫ

### Класс GameLogic (логика игры):

```csharp
using System;
using System.Collections.Generic;

namespace TicTacToe
{
    public class GameLogic
    {
        private const int BoardSize = 10;
        private const int WinLength = 5;
        
        private int[,] board;  // 0 = пусто, 1 = X (игрок 1), 2 = O (игрок 2)
        private int currentPlayer;
        private int player1Score;
        private int player2Score;
        private bool gameOver;

        public int CurrentPlayer => currentPlayer;
        public int Player1Score => player1Score;
        public int Player2Score => player2Score;
        public bool GameOver => gameOver;

        public GameLogic()
        {
            board = new int[BoardSize, BoardSize];
            currentPlayer = 1;
            player1Score = 0;
            player2Score = 0;
            gameOver = false;
        }

        public int GetCell(int row, int col)
        {
            if (row < 0 || row >= BoardSize || col < 0 || col >= BoardSize)
                return -1;
            return board[row, col];
        }

        public bool MakeMove(int row, int col)
        {
            if (gameOver || row < 0 || row >= BoardSize || col < 0 || col >= BoardSize)
                return false;

            if (board[row, col] != 0)
                return false;

            board[row, col] = currentPlayer;
            return true;
        }

        public void SwitchPlayer()
        {
            currentPlayer = currentPlayer == 1 ? 2 : 1;
        }

        public (bool hasWinner, int winner, List<(int, int)> winningCells) CheckWin()
        {
            // Проверка всех возможных выигрышных комбинаций
            for (int row = 0; row < BoardSize; row++)
            {
                for (int col = 0; col < BoardSize; col++)
                {
                    int player = board[row, col];
                    if (player == 0) continue;

                    // Проверка горизонтали (→)
                    if (col + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row, col + i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row, col + i));
                            return (true, player, cells);
                        }
                    }

                    // Проверка вертикали (↓)
                    if (row + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col));
                            return (true, player, cells);
                        }
                    }

                    // Проверка диагонали (\)
                    if (row + WinLength <= BoardSize && col + WinLength <= BoardSize)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col + i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col + i));
                            return (true, player, cells);
                        }
                    }

                    // Проверка диагонали (/)
                    if (row + WinLength <= BoardSize && col - WinLength + 1 >= 0)
                    {
                        bool win = true;
                        for (int i = 1; i < WinLength; i++)
                        {
                            if (board[row + i, col - i] != player)
                            {
                                win = false;
                                break;
                            }
                        }
                        if (win)
                        {
                            var cells = new List<(int, int)>();
                            for (int i = 0; i < WinLength; i++)
                                cells.Add((row + i, col - i));
                            return (true, player, cells);
                        }
                    }
                }
            }

            return (false, 0, new List<(int, int)>());
        }

        public bool CheckDraw()
        {
            for (int row = 0; row < BoardSize; row++)
            {
                for (int col = 0; col < BoardSize; col++)
                {
                    if (board[row, col] == 0)
                        return false;
                }
            }
            return true;
        }

        public void SetGameOver()
        {
            gameOver = true;
        }

        public void UpdateScore(int winner)
        {
            if (winner == 1)
                player1Score++;
            else if (winner == 2)
                player2Score++;
        }

        public void ResetGame()
        {
            board = new int[BoardSize, BoardSize];
            currentPlayer = 1;
            gameOver = false;
        }

        public void ResetScore()
        {
            player1Score = 0;
            player2Score = 0;
        }
    }
}
```

---

### Графический интерфейс (MainWindow.axaml):

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="TicTacToe.Views.MainWindow"
        Title="Крестики-нолики 10x10"
        Width="700" Height="800">
    
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>  <!-- Счет -->
            <RowDefinition Height="*"/>      <!-- Игровое поле -->
            <RowDefinition Height="Auto"/>  <!-- Кнопки -->
        </Grid.RowDefinitions>
        
        <!-- Панель счета -->
        <Border Grid.Row="0" BorderBrush="Gray" BorderThickness="1" 
                Padding="10" Margin="0,0,0,10" Background="#F0F0F0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <TextBlock Name="Player1ScoreLabel" Grid.Column="0"
                          Text="Игрок 1 (X): 0"
                          FontSize="16" FontWeight="Bold"
                          Foreground="Blue"
                          VerticalAlignment="Center"/>
                
                <TextBlock Name="CurrentPlayerLabel" Grid.Column="1"
                          Text="Ход: Игрок 1"
                          FontSize="16" FontWeight="Bold"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Center"/>
                
                <TextBlock Name="Player2ScoreLabel" Grid.Column="2"
                          Text="Игрок 2 (O): 0"
                          FontSize="16" FontWeight="Bold"
                          Foreground="Red"
                          HorizontalAlignment="Right"
                          VerticalAlignment="Center"/>
            </Grid>
        </Border>
        
        <!-- Canvas для игрового поля -->
        <Border Grid.Row="1" BorderBrush="Black" BorderThickness="2" 
                Margin="0,0,0,10">
            <Canvas Name="GameCanvas"
                    Width="600" Height="600"
                    Background="White"
                    PointerPressed="OnCanvasClick"
                    ClipToBounds="True"/>
        </Border>
        
        <!-- Кнопки управления -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" 
                    HorizontalAlignment="Center" Spacing="20">
            <Button Name="NewGameButton" 
                   Content="Новая игра" 
                   Click="OnNewGame"
                   Width="150" Height="40"
                   FontSize="16"/>
            <Button Name="ResetScoreButton" 
                   Content="Сбросить счет" 
                   Click="OnResetScore"
                   Width="150" Height="40"
                   FontSize="16"/>
        </StackPanel>
    </Grid>
</Window>
```

---

### Логика интерфейса (MainWindow.axaml.cs) - ключевые фрагменты:

```csharp
public partial class MainWindow : Window
{
    private const int BoardSize = 10;
    private const double CellSize = 60;
    
    private GameLogic gameLogic;
    
    public MainWindow()
    {
        InitializeComponent();
        gameLogic = new GameLogic();
        DrawBoard();
        UpdateUI();
    }

    // Отрисовка игрового поля
    private void DrawBoard()
    {
        GameCanvas.Children.Clear();
        
        // Рисуем сетку 10x10
        for (int i = 0; i <= BoardSize; i++)
        {
            // Вертикальные и горизонтальные линии
            var vLine = new Line { /* параметры */ };
            var hLine = new Line { /* параметры */ };
            GameCanvas.Children.Add(vLine);
            GameCanvas.Children.Add(hLine);
        }
        
        // Рисуем X и O
        for (int row = 0; row < BoardSize; row++)
        {
            for (int col = 0; col < BoardSize; col++)
            {
                int cell = gameLogic.GetCell(row, col);
                if (cell == 1) DrawX(row, col);
                else if (cell == 2) DrawO(row, col);
            }
        }
    }

    // Обработка клика мыши
    private void OnCanvasClick(object? sender, PointerPressedEventArgs e)
    {
        if (gameLogic.GameOver) return;
        
        var point = e.GetPosition(GameCanvas);
        int col = (int)(point.X / CellSize);
        int row = (int)(point.Y / CellSize);
        
        if (gameLogic.MakeMove(row, col))
        {
            DrawBoard();
            CheckGameEnd();
            
            if (!gameLogic.GameOver)
            {
                gameLogic.SwitchPlayer();
                UpdateUI();
            }
        }
    }

    // Проверка окончания игры
    private async void CheckGameEnd()
    {
        var (hasWinner, winner, cells) = gameLogic.CheckWin();
        
        if (hasWinner)
        {
            DrawWinningLine(cells);
            gameLogic.SetGameOver();
            gameLogic.UpdateScore(winner);
            UpdateUI();
            
            string playerName = winner == 1 ? "Игрок 1 (X)" : "Игрок 2 (O)";
            await ShowMessageBox("Победа!", $"{playerName} победил!");
        }
        else if (gameLogic.CheckDraw())
        {
            gameLogic.SetGameOver();
            await ShowMessageBox("Ничья!", "Игра закончилась вничью!");
        }
    }

    // Отрисовка выигрышной линии
    private void DrawWinningLine(List<(int, int)> winningCells)
    {
        var firstCell = winningCells.First();
        var lastCell = winningCells.Last();
        
        double x1 = firstCell.Item2 * CellSize + CellSize / 2;
        double y1 = firstCell.Item1 * CellSize + CellSize / 2;
        double x2 = lastCell.Item2 * CellSize + CellSize / 2;
        double y2 = lastCell.Item1 * CellSize + CellSize / 2;
        
        var winLine = new Line
        {
            StartPoint = new Point(x1, y1),
            EndPoint = new Point(x2, y2),
            Stroke = Brushes.Green,
            StrokeThickness = 5
        };
        GameCanvas.Children.Add(winLine);
    }
}
```

---

## РЕКОМЕНДУЕМЫЕ СКРИНШОТЫ

### Скриншоты кода:
1. GameLogic.cs (весь файл)
2. MainWindow.axaml (XAML разметка)
3. MainWindow.axaml.cs (ключевые методы: DrawBoard, OnCanvasClick, CheckWin)

### Скриншоты работы приложения:
1. Начало игры (пустое поле 10×10 с сеткой)
2. Процесс игры (несколько ходов X синими и O красными)
3. Победа по горизонтали (5 X в ряд + зеленая линия)
4. Победа по вертикали (5 O в ряд + зеленая линия)
5. Победа по диагонали (\) (5 символов + зеленая линия)
6. Победа по диагонали (/) (5 символов + зеленая линия)
7. MessageBox с результатом победы
8. Счет игроков после нескольких раундов (например, 3:2)
9. Ничья (поле полностью заполнено)
10. MessageBox с сообщением о ничьей

---

## ОСОБЕННОСТИ РЕАЛИЗАЦИИ

### Алгоритм проверки победы

Для каждой заполненной клетки проверяются 4 направления:
1. **Горизонталь (→)**: проверка 5 подряд в строке
2. **Вертикаль (↓)**: проверка 5 подряд в столбце
3. **Диагональ (\)**: проверка 5 подряд по главной диагонали
4. **Диагональ (/)**: проверка 5 подряд по побочной диагонали

При нахождении 5 символов одного игрока подряд:
- Возвращается информация о победителе
- Возвращается список координат выигрышных клеток
- Рисуется зеленая линия через центры выигрышных клеток

### Адаптация Windows Forms → Avalonia UI

| Требование задания | Windows Forms | Avalonia UI | Реализация |
|-------------------|---------------|-------------|------------|
| Отрисовка графики | Paint event | Canvas.Children | Line, Ellipse |
| Обработка клика | MouseClick (e.X, e.Y) | PointerPressed (e.GetPosition) | OnCanvasClick |
| MessageBox | MessageBox.Show() | Custom Window.ShowDialog() | ShowMessageBox |
| Сетка | Graphics.DrawLine() | new Line() | DrawBoard |
| Крестики | Graphics.DrawLine() | new Line() (2 диагонали) | DrawX |
| Нолики | Graphics.DrawEllipse() | new Ellipse() | DrawO |
| Выигрышная линия | Graphics.DrawLine() | new Line() (жирная зеленая) | DrawWinningLine |

### Хранение состояния

Двумерный массив `int[10,10]`:
- `0` - пустая клетка
- `1` - крестик (X, игрок 1)
- `2` - нолик (O, игрок 2)

### Цветовая схема

- **X (Игрок 1)**: синий цвет (Blue)
- **O (Игрок 2)**: красный цвет (Red)
- **Выигрышная линия**: зеленый цвет (Green)
- **Сетка**: черный цвет (Black)

---

## ВЫВОД

В ходе выполнения лабораторной работы я успешно реализовал игру "Крестики-нолики" на поле 10×10 с условием победы 5 символов в ряд, выполнив все требования уровня 2 для получения максимального балла (+4). Разработал полнофункциональное приложение с графическим интерфейсом на платформе Avalonia UI, которая является кроссплатформенной альтернативой Windows Forms и позволяет запускать приложение на macOS.

Реализовал класс GameLogic, инкапсулирующий всю игровую логику: хранение состояния игрового поля в двумерном массиве `int[10,10]`, управление ходами игроков, проверку условий победы и ничьей, ведение счета. Разработал эффективный алгоритм проверки победы, который для каждой заполненной клетки проверяет 4 направления (горизонталь, вертикаль, две диагонали) на наличие 5 символов подряд. Алгоритм возвращает не только информацию о победителе, но и координаты выигрышных клеток, что необходимо для визуализации выигрышной комбинации.

Создал графический интерфейс с использованием XAML-разметки и Canvas для отрисовки игрового поля. Реализовал отрисовку сетки 10×10 через добавление визуальных элементов Line на Canvas, крестиков через две диагональные линии синего цвета, ноликов через Ellipse красного цвета. Разработал систему обработки кликов мыши через событие PointerPressed, которое определяет координаты клетки по позиции клика и вызывает соответствующую логику хода. Реализовал отображение выигрышной комбинации через жирную зеленую линию, соединяющую центры 5 выигрышных клеток.

Освоил адаптацию требований Windows Forms под Avalonia UI: заменил событие Paint на ручное добавление визуальных элементов в Canvas.Children, MouseClick на PointerPressed с получением координат через e.GetPosition(), MessageBox.Show() на создание кастомного диалогового окна через Window.ShowDialog(). Понял, что Avalonia использует более современный подход к отрисовке через добавление готовых визуальных элементов (Line, Ellipse, Rectangle) вместо процедурной отрисовки через Graphics.

Реализовал полный функционал управления игрой: панель счета с отображением текущего игрока и результатов, кнопки "Новая игра" для начала нового раунда с сохранением счета и "Сбросить счет" для полного обнуления. Добавил вывод MessageBox с именем победителя или сообщением о ничьей по окончании каждого раунда. Обеспечил корректное чередование ходов игроков и блокировку дальнейших ходов после окончания игры до нажатия кнопки "Новая игра".

Полученные навыки работы с графическим интерфейсом, обработкой событий мыши, отрисовкой визуальных элементов и разработкой игровой логики являются важными для создания интерактивных приложений. Освоил работу с кроссплатформенным UI-фреймворком Avalonia, что позволяет создавать приложения, работающие на Windows, macOS и Linux. Научился правильно разделять логику (GameLogic) и представление (MainWindow), что обеспечивает чистоту архитектуры и упрощает тестирование. Эти знания станут основой для разработки более сложных графических приложений, игр и интерактивных систем на платформе .NET.
