"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSwitchboardAddressFromAllAddresses = exports.getDeCapacitorAddressFromAllAddresses = exports.getCapacitorAddressFromAllAddresses = exports.getAllAddresses = exports.getAddresses = exports.getDeCapacitorAddress = exports.getCapacitorAddress = exports.getSwitchboardAddress = void 0;
// TODO: This is duplicate from socket-dl and should be in its own module
const _1 = require("./");
const dev_addresses_json_1 = __importDefault(require("../deployments/dev_addresses.json"));
const prod_addresses_json_1 = __importDefault(require("../deployments/prod_addresses.json"));
const surge_addresses_json_1 = __importDefault(require("../deployments/surge_addresses.json"));
function getAllAddresses(mode) {
    let addresses;
    switch (mode) {
        case _1.DeploymentMode.DEV:
            addresses = dev_addresses_json_1.default;
            break;
        case _1.DeploymentMode.PROD:
            addresses = prod_addresses_json_1.default;
            break;
        case _1.DeploymentMode.SURGE:
            addresses = surge_addresses_json_1.default;
            break;
        default:
            throw new Error("No Mode Provided");
    }
    if (!addresses)
        throw new Error("addresses not found");
    return addresses;
}
exports.getAllAddresses = getAllAddresses;
function getAddresses(srcChainSlug, mode) {
    let addresses = getAllAddresses(mode)[srcChainSlug];
    if (!addresses)
        throw new Error("addresses not found");
    return addresses;
}
exports.getAddresses = getAddresses;
function getSwitchboardAddress(srcChainSlug, dstChainSlug, integration, mode) {
    var _a, _b, _c;
    const addr = getAddresses(srcChainSlug, mode);
    const switchboardAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.switchboard;
    if (!switchboardAddress) {
        throw new Error(`Switchboard address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return switchboardAddress;
}
exports.getSwitchboardAddress = getSwitchboardAddress;
function getSwitchboardAddressFromAllAddresses(allAddresses, srcChainSlug, dstChainSlug, integration) {
    var _a, _b, _c;
    const addr = allAddresses[srcChainSlug];
    if (!addr) {
        throw new Error(`Addresses for ${srcChainSlug} not found`);
    }
    const switchboardAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.switchboard;
    if (!switchboardAddress) {
        throw new Error(`Switchboard address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return switchboardAddress;
}
exports.getSwitchboardAddressFromAllAddresses = getSwitchboardAddressFromAllAddresses;
function getCapacitorAddress(srcChainSlug, dstChainSlug, integration, mode) {
    var _a, _b, _c;
    const addr = getAddresses(srcChainSlug, mode);
    const capacitorAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.capacitor;
    if (!capacitorAddress) {
        throw new Error(`Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return capacitorAddress;
}
exports.getCapacitorAddress = getCapacitorAddress;
function getCapacitorAddressFromAllAddresses(allAddresses, srcChainSlug, dstChainSlug, integration) {
    var _a, _b, _c;
    const addr = allAddresses[srcChainSlug];
    if (!addr) {
        throw new Error(`Addresses for ${srcChainSlug} not found`);
    }
    const capacitorAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.capacitor;
    if (!capacitorAddress) {
        throw new Error(`Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return capacitorAddress;
}
exports.getCapacitorAddressFromAllAddresses = getCapacitorAddressFromAllAddresses;
function getDeCapacitorAddress(srcChainSlug, dstChainSlug, integration, mode) {
    var _a, _b, _c;
    const addr = getAddresses(srcChainSlug, mode);
    const deCapacitorAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.capacitor;
    if (!deCapacitorAddress) {
        throw new Error(`De Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return deCapacitorAddress;
}
exports.getDeCapacitorAddress = getDeCapacitorAddress;
function getDeCapacitorAddressFromAllAddresses(allAddresses, srcChainSlug, dstChainSlug, integration) {
    var _a, _b, _c;
    const addr = allAddresses[srcChainSlug];
    if (!addr) {
        throw new Error(`Addresses for ${srcChainSlug} not found`);
    }
    const deCapacitorAddress = (_c = (_b = (_a = addr === null || addr === void 0 ? void 0 : addr["integrations"]) === null || _a === void 0 ? void 0 : _a[dstChainSlug]) === null || _b === void 0 ? void 0 : _b[integration]) === null || _c === void 0 ? void 0 : _c.capacitor;
    if (!deCapacitorAddress) {
        throw new Error(`De Capacitor address for ${srcChainSlug}-${dstChainSlug}-${integration} not found`);
    }
    return deCapacitorAddress;
}
exports.getDeCapacitorAddressFromAllAddresses = getDeCapacitorAddressFromAllAddresses;
