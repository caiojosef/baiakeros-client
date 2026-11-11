-- Baiakeros local development environment. Public releases use environment.production.lua.

-- Baiakeros 15.25 protocol with the existing adapted 15.25 appearance catalog.
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
        protocol = 1525,
        httpLogin = false,
        useAuthenticator = false
    }
}
