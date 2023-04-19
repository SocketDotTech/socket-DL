import SocketABI from "@socket.tech/dl-core/artifacts/abi/Socket.json";
import TransmitManagerABI from "@socket.tech/dl-core/artifacts/abi/TransmitManager.json";
import CapacitorFactoryABI from "@socket.tech/dl-core/artifacts/abi/CapacitorFactory.json";
import ExecutionManagerABI from "@socket.tech/dl-core/artifacts/abi/ExecutionManager.json";
import GasPriceOracleABI from "@socket.tech/dl-core/artifacts/abi/GasPriceOracle.json";
import DecapacitorABI from "@socket.tech/dl-core/artifacts/abi/IDecapacitor.json";
import CapacitorABI from "@socket.tech/dl-core/artifacts/abi/ICapacitor.json";
import FastSwitchboard from "@socket.tech/dl-core/artifacts/abi/FastSwitchboard.json";
import OptimisticSwitchboard from "@socket.tech/dl-core/artifacts/abi/OptimisticSwitchboard.json";
import NativeSwitchboard from "@socket.tech/dl-core/artifacts/abi/ArbitrumL1Switchboard.json";
import AccessControlExtended from "@socket.tech/dl-core/artifacts/abi/AccessControlExtended.json";

export const getABI = {
  TransmitManager: TransmitManagerABI,
  CapacitorFactory: CapacitorFactoryABI,
  ExecutionManager: ExecutionManagerABI,
  GasPriceOracle: GasPriceOracleABI,
  Decapacitor: DecapacitorABI,
  Capacitor: CapacitorABI,
  Socket: SocketABI,
  FastSwitchboard,
  OptimisticSwitchboard,
  NativeSwitchboard,
  AccessControlExtended,
};
