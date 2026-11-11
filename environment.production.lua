-- Baiakeros public production environment.
-- During staging this file is copied to the runtime as environment.lua.

-- Baiakeros 15.25 protocol with the existing adapted 15.25 appearance catalog.
CLIENT_ASSET_VERSION = 1525

Services = {
    status = "https://www.baiakeros.com/login.php",
    clientManifest = "https://www.baiakeros.com/downloads/client/client.windows.json",
    websites = "https://www.baiakeros.com/",
    market = "https://www.baiakeros.com",
    forgotPassword = "https://www.baiakeros.com/index.php/account/lost",
    discord = "https://discord.gg/6FET9zsWj",
    createAccount = "https://www.baiakeros.com/index.php/account/create",
    getCoinsUrl = "https://www.baiakeros.com/index.php/donations",
    clientAssets = false
}

Servers_init = {
    ["https://www.baiakeros.com/login.php"] = {
        port = 443,
        protocol = 1525,
        httpLogin = false,
        useAuthenticator = false
    }
}
