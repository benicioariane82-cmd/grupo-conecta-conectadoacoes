$ErrorActionPreference = "Stop"

$arquivo = Join-Path (Get-Location) "scripts\area.js"

if (!(Test-Path $arquivo)) {
    throw "Não encontrei scripts\area.js. Abra o terminal na pasta principal do projeto."
}

$codigo = Get-Content $arquivo -Raw

$novaFuncao = @'
async function submitAuth(event, type, register) {
    event.preventDefault();

    const values = new FormData(event.currentTarget);
    const password = String(values.get('password') || '');

    const payload = { password };

    if (type === 'beneficiary') {
        payload.cpf = digits(values.get('cpf'));

        if (register) {
            payload.name = String(values.get('name') || '').trim();
            payload.phone = String(values.get('phone') || '').trim();
        }
    } else {
        payload.email = String(values.get('email') || '').trim().toLowerCase();

        if (register) {
            payload.name = String(values.get('name') || '').trim();
            payload.cnpj = digits(values.get('cnpj'));
            payload.city = String(values.get('city') || '').trim();
        }
    }

    if (register && password.length < 6) {
        return toast('A senha precisa ter pelo menos 6 caracteres.');
    }

    if (type === 'beneficiary' && payload.cpf.length !== 11) {
        return toast('Informe um CPF com 11 números.');
    }

    if (type === 'ong' && register && payload.cnpj.length !== 14) {
        return toast('Informe um CNPJ com 14 números.');
    }

    const endpoint = register
        ? (type === 'ong' ? 'register/ong' : 'register/beneficiary')
        : 'login';

    if (!register) {
        payload.type = type;
    }

    try {
        const response = await fetch(
            `http://127.0.0.1:5000/api/auth/${endpoint}`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            }
        );

        const result = await response.json();

        if (!response.ok) {
            return toast(result.message || result.error || 'Não foi possível realizar o acesso.');
        }

        if (!result.account || !result.token) {
            return toast('O servidor respondeu, mas não retornou os dados da sessão.');
        }

        createSession(type, result.account, result.token);

    } catch (error) {
        toast('Não foi possível conectar ao servidor Flask.');
        console.error(error);
    }
}
'@

$padrao = '(?s)async function submitAuth\(event, type, register\)\s*\{.*?\r?\n\}\s*(?=function initAuth\(type\))'

if (-not [regex]::IsMatch($codigo, $padrao)) {
    throw "Não encontrei a função submitAuth no formato esperado. Nenhuma alteração foi feita."
}

$backup = "$arquivo.bak"
Copy-Item $arquivo $backup -Force

$codigoAtualizado = [regex]::Replace($codigo, $padrao, $novaFuncao + "`r`n", 1)
Set-Content -Path $arquivo -Value $codigoAtualizado -Encoding UTF8

Write-Host "Alteração aplicada com sucesso em scripts\area.js"
Write-Host "Backup original salvo em scripts\area.js.bak"
Write-Host "Agora confira o arquivo no VS Code e salve, se necessário."
