"use strict";
function required(name) {
    const value = process.env[name];
    if (!value) throw new Error("Falta variable " + name);
    return value;
}
function hash(name) {
    const value = required(name);
    if (!/^\$2[aby]\$(0[89]|1[0-6])\$[./A-Za-z0-9]{53}$/.test(value)) {
        throw new Error(name + ": configurar bcrypt válido con coste entre 8 y 16");
    }
    return value;
}
const secret = required("NR_CREDENTIAL_SECRET");
if (!/^[a-f0-9]{64}$/.test(secret)) throw new Error("NR_CREDENTIAL_SECRET debe ser 64 caracteres hex");
module.exports = {
    uiPort: 1880,
    userDir: "/data",
    flowFile: "flows.json",
    flowFilePretty: true,
    credentialSecret: secret,
    httpAdminRoot: "/editor",
    httpNodeRoot: "/api",
    adminAuth: {
        type: "credentials",
        sessionExpiryTime: 3600,
        users: [{username: required("NR_ADMIN_USER"), password: hash("NR_ADMIN_HASH"), permissions: "*"}]
    },
    httpNodeAuth: {user: required("NR_HTTP_USER"), pass: hash("NR_HTTP_HASH")},
    contextStorage: {
        default: {module: "memory"},
        durable: {module: "localfilesystem"}
    },
    functionExternalModules: false,
    externalModules: {
        autoInstall: false,
        palette: {allowInstall: false, allowUpdate: false, allowUpload: false},
        modules: {allowInstall: false}
    },
    editorTheme: {projects: {enabled: false}},
    logging: {console: {level: "info", metrics: false, audit: false}}
};
