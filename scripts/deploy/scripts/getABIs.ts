import Socket from "../../../out/Socket.sol/Socket.json";
import TransmitManager from "../../../out/TransmitManager.sol/TransmitManager.json";
import CapacitorFactory from "../../../out/CapacitorFactory.sol/CapacitorFactory.json";
import ExecutionManager from "../../../out/ExecutionManager.sol/ExecutionManager.json";
import Decapacitor from "../../../out/IDecapacitor.sol/IDecapacitor.json";
import Capacitor from "../../../out/ICapacitor.sol/ICapacitor.json";
import FastSwitchboard from "../../../out/FastSwitchboard.sol/FastSwitchboard.json";
import OptimisticSwitchboard from "../../../out/OptimisticSwitchboard.sol/OptimisticSwitchboard.json";
import NativeSwitchboard from "../../../out/ArbitrumL1Switchboard.sol/ArbitrumL1Switchboard.json";
import AccessControlExtended from "../../../out/AccessControlExtended.sol/AccessControlExtended.json";

export const getABI = {
  TransmitManager: TransmitManager.abi,
  CapacitorFactory: CapacitorFactory.abi,
  ExecutionManager: ExecutionManager.abi,
  OpenExecutionManager: ExecutionManager.abi,
  Decapacitor: Decapacitor.abi,
  Capacitor: Capacitor.abi,
  Socket: Socket.abi,
  FastSwitchboard: FastSwitchboard.abi,
  OptimisticSwitchboard: OptimisticSwitchboard.abi,
  NativeSwitchboard: NativeSwitchboard.abi,
  AccessControlExtended: AccessControlExtended.abi,
};
