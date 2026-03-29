part of '../rpc_module_generator.dart';

const _moduleChecker = TypeChecker.typeNamed(
  Module,
  inPackage: 'dart_orpc_annotations',
);
const _controllerChecker = TypeChecker.typeNamed(
  Controller,
  inPackage: 'dart_orpc_annotations',
);
const _rpcInputChecker = TypeChecker.typeNamed(
  RpcInput,
  inPackage: 'dart_orpc_annotations',
);
const _rpcMethodChecker = TypeChecker.typeNamed(
  RpcMethod,
  inPackage: 'dart_orpc_annotations',
);
const _rpcContextChecker = TypeChecker.typeNamed(
  RpcContext,
  inPackage: 'dart_orpc_core',
);
const _pathParamChecker = TypeChecker.typeNamed(
  PathParam,
  inPackage: 'dart_orpc_annotations',
);
const _queryParamChecker = TypeChecker.typeNamed(
  QueryParam,
  inPackage: 'dart_orpc_annotations',
);
const _bodyChecker = TypeChecker.typeNamed(
  Body,
  inPackage: 'dart_orpc_annotations',
);
const _fromPathChecker = TypeChecker.typeNamed(
  FromPath,
  inPackage: 'dart_orpc_annotations',
);
const _fromQueryChecker = TypeChecker.typeNamed(
  FromQuery,
  inPackage: 'dart_orpc_annotations',
);
const _fromHeaderChecker = TypeChecker.typeNamed(
  FromHeader,
  inPackage: 'dart_orpc_annotations',
);
const _luthorChecker = TypeChecker.typeNamed(Luthor, inPackage: 'luthor');
