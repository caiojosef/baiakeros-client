-- Baiakeros local development environment. Public releases use environment.production.lua.

-- Keep the 15.11 network protocol while loading the complete 15.25 appearance catalog.
CLIENT_ASSET_VERSION = 1525

Services = {
    status = "http://localhost/login.php",
    clientManifest = false,
    websites = "http://localhost/",
    market = "http://localhost",
    forgotPassword = "http://localhost/index.php/account/lost",
    discord = "https://discord.gg/6FET9zsWj",
    createAccount = "http://localhost/index.php/account/create",
    getCoinsUrl = "http://localhost/index.php/donations",
    clientAssets = false
}
Servers_init = {
    ["http://localhost/login.php"] = {
        port = 80,
        protocol = 1511,
        httpLogin = false,
        useAuthenticator = false
    }
}
