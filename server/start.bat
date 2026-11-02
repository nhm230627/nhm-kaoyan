@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo  复试专 BFF 代理服务
echo ============================================
echo.

if not exist ".key" (
  if "%DEEPSEEK_API_KEY%"=="" (
    echo [!] 没有找到 .key 文件，也没有设置 DEEPSEEK_API_KEY
    echo     所有 AI 接口会返回 503。放好 Key 后再启动。
    echo.
  )
)

if not exist "node_modules" (
  echo [i] 本服务零依赖，不需要 npm install
)

node index.mjs

echo.
echo [服务已停止] 按任意键关闭窗口
pause >nul
