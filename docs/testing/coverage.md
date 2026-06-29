# Test Coverage Guide (Flutter/Dart)

Flutter uses `lcov` for coverage, which is the equivalent of Jacoco for Java.

## 1. Generate Coverage Data
Run all tests with the coverage flag:
```bash
flutter test --coverage
```
This generates a `coverage/lcov.info` file in the project root.

## 2. Visualize Coverage (HTML Report)
To convert the `lcov.info` file into a readable HTML website, you need the `lcov` tool installed on your system.

### Installation
- **Linux**: `sudo apt-get install lcov`
- **macOS**: `brew install lcov`
- **Windows**: Install via Chocolatey `choco install lcov` or use WSL.

### Generate HTML
Run these commands in the project root:
```bash
genhtml coverage/lcov.info -o coverage/html
```
Then open `coverage/html/index.html` in your browser.

## 3. Summary of Coverage
To see a quick summary in the terminal:
```bash
lcov --list coverage/lcov.info
```
