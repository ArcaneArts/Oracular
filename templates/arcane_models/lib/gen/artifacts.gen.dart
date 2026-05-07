// GENERATED – do not modify by hand

// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: constant_identifier_names
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: unused_element
import "package:arcane_models/arcane_models.dart";import "package:artifact/artifact.dart";import "dart:core";
typedef _0=ArtifactCodecUtil;typedef _1=ArtifactDataUtil;typedef _2=ArtifactSecurityUtil;typedef _3=ArtifactReflection;typedef _4=ArtifactMirror;typedef _5=Map<String,dynamic>;typedef _6=List<String>;typedef _7=String;typedef _8=dynamic;typedef _9=int;typedef _a=ArtifactModelExporter;typedef _b=ArgumentError;typedef _c=Exception;typedef _d=User;typedef _e=UserSettings;typedef _f=ServerCommand;typedef _g=ServerResponse;typedef _h=ResponseOK;typedef _i=ResponseError;typedef _j=ArcaneServerSignature;typedef _k=ArtifactModelImporter<User>;typedef _l=bool;typedef _m=ArtifactModelImporter<UserSettings>;typedef _n=ThemeMode;typedef _o=ArtifactModelImporter<ServerCommand>;typedef _p=ArtifactModelImporter<ServerResponse>;typedef _q=ArtifactModelImporter<ResponseOK>;typedef _r=ArtifactModelImporter<ResponseError>;typedef _s=ArtifactModelImporter<ArcaneServerSignature>;typedef _t=ArtifactAccessor;typedef _u=List<dynamic>;
_b __x(_7 c,_7 f)=>_b('${_S[17]}$c.$f');
const _6 _S=['name','email','profileHash','User','themeMode','user','ServerCommand','_subclass_ServerResponse','ResponseOK','ResponseError','ServerResponse','message','signature','session','time','ArcaneServerSignature','arcane_models','Missing required '];const _u _V=[ThemeMode.system];const _l _T=true;const _l _F=false;_9 _ = ((){if(!_t.$i(_S[16])){_t.$r(_S[16],_t(isArtifact: $isArtifact,artifactMirror:{},constructArtifact:$constructArtifact,artifactToMap:$artifactToMap,artifactFromMap:$artifactFromMap));}return 0;})();

extension $User on _d{
  _d get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[0]:_0.ea(name),_S[1]:_0.ea(email),_S[2]:_0.ea(profileHash),}.$nn;}
  static _k get from=>_k(fromMap);
  static _d fromMap(_5 r){_;_5 m=r.$nn;return _d(name: m.$c(_S[0])? _0.da(m[_S[0]], _7) as _7:throw __x(_S[3],_S[0]),email: m.$c(_S[1])? _0.da(m[_S[1]], _7) as _7:throw __x(_S[3],_S[1]),profileHash: m.$c(_S[2]) ?  _0.da(m[_S[2]], _7) as _7? : null,);}
  _d copyWith({_7? name,_7? email,_7? profileHash,_l deleteProfileHash=_F,})=>_d(name: name??_H.name,email: email??_H.email,profileHash: deleteProfileHash?null:(profileHash??_H.profileHash),);
  static _d get newInstance=>_d(name: '',email: '',);
}
extension $UserSettings on _e{
  _e get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[4]:themeMode.name,}.$nn;}
  static _m get from=>_m(fromMap);
  static _e fromMap(_5 r){_;_5 m=r.$nn;return _e(themeMode: m.$c(_S[4]) ? _1.e(ThemeMode.values, m[_S[4]]) as ThemeMode : _V[0],);}
  _e copyWith({_n? themeMode,_l resetThemeMode=_F,})=>_e(themeMode: resetThemeMode?_V[0]:(themeMode??_H.themeMode),);
  static _e get newInstance=>_e();
}
extension $ServerCommand on _f{
  _f get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[5]:_0.ea(user),}.$nn;}
  static _o get from=>_o(fromMap);
  static _f fromMap(_5 r){_;_5 m=r.$nn;return _f(user: m.$c(_S[5])? _0.da(m[_S[5]], _7) as _7:throw __x(_S[6],_S[5]),);}
  _f copyWith({_7? user,})=>_f(user: user??_H.user,);
  static _f get newInstance=>_f(user: '',);
}
extension $ServerResponse on _g{
  _g get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;if (_H is _h){return (_H as _h).toMap();}if (_H is _i){return (_H as _i).toMap();}return<_7,_8>{_S[5]:_0.ea(user),}.$nn;}
  static _p get from=>_p(fromMap);
  static _g fromMap(_5 r){_;_5 m=r.$nn;if(m.$c(_S[7])){String _I=m[_S[7]] as _7;if(_I==_S[8]){return $ResponseOK.fromMap(m);}if(_I==_S[9]){return $ResponseError.fromMap(m);}}return _g(user: m.$c(_S[5])? _0.da(m[_S[5]], _7) as _7:throw __x(_S[10],_S[5]),);}
  _g copyWith({_7? user,}){if (_H is _h){return (_H as _h).copyWith(user: user,);}if (_H is _i){return (_H as _i).copyWith(user: user,);}return _g(user: user??_H.user,);}
  static _g get newInstance=>_g(user: '',);
}
extension $ResponseOK on _h{
  _h get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[7]: 'ResponseOK',_S[5]:_0.ea(user),}.$nn;}
  static _q get from=>_q(fromMap);
  static _h fromMap(_5 r){_;_5 m=r.$nn;return _h(user: m.$c(_S[5])? _0.da(m[_S[5]], _7) as _7:throw __x(_S[8],_S[5]),);}
  _h copyWith({_7? user,})=>_h(user: user??_H.user,);
  static _h get newInstance=>_h(user: '',);
}
extension $ResponseError on _i{
  _i get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[7]: 'ResponseError',_S[5]:_0.ea(user),_S[11]:_0.ea(message),}.$nn;}
  static _r get from=>_r(fromMap);
  static _i fromMap(_5 r){_;_5 m=r.$nn;return _i(user: m.$c(_S[5])? _0.da(m[_S[5]], _7) as _7:throw __x(_S[9],_S[5]),message: m.$c(_S[11])? _0.da(m[_S[11]], _7) as _7:throw __x(_S[9],_S[11]),);}
  _i copyWith({_7? user,_7? message,})=>_i(user: user??_H.user,message: message??_H.message,);
  static _i get newInstance=>_i(user: '',message: '',);
}
extension $ArcaneServerSignature on _j{
  _j get _H=>this;
  _a get to=>_a(toMap);
  _5 toMap(){_;return<_7,_8>{_S[12]:_0.ea(signature),_S[13]:_0.ea(session),_S[14]:_0.ea(time),}.$nn;}
  static _s get from=>_s(fromMap);
  static _j fromMap(_5 r){_;_5 m=r.$nn;return _j(signature: m.$c(_S[12])? _0.da(m[_S[12]], _7) as _7:throw __x(_S[15],_S[12]),session: m.$c(_S[13])? _0.da(m[_S[13]], _7) as _7:throw __x(_S[15],_S[13]),time: m.$c(_S[14])? _0.da(m[_S[14]], _9) as _9:throw __x(_S[15],_S[14]),);}
  _j copyWith({_7? signature,_7? session,_9? time,_9? deltaTime,})=>_j(signature: signature??_H.signature,session: session??_H.session,time: deltaTime!=null?(time??_H.time)+deltaTime:time??_H.time,);
  static _j get newInstance=>_j(signature: '',session: '',time: 0,);
}

bool $isArtifact(dynamic v)=>v==null?false : v is! Type ?$isArtifact(v.runtimeType):v == _d ||v == _e ||v == _f ||v == _g ||v == _h ||v == _i ||v == _j ;
T $constructArtifact<T>() => T==_d ?$User.newInstance as T :T==_e ?$UserSettings.newInstance as T :T==_f ?$ServerCommand.newInstance as T :T==_g ?$ServerResponse.newInstance as T :T==_h ?$ResponseOK.newInstance as T :T==_i ?$ResponseError.newInstance as T :T==_j ?$ArcaneServerSignature.newInstance as T : throw _c();
_5 $artifactToMap(Object o)=>o is _d ?o.toMap():o is _e ?o.toMap():o is _f ?o.toMap():o is _g ?o.toMap():o is _h ?o.toMap():o is _i ?o.toMap():o is _j ?o.toMap():throw _c();
T $artifactFromMap<T>(_5 m)=>T==_d ?$User.fromMap(m) as T:T==_e ?$UserSettings.fromMap(m) as T:T==_f ?$ServerCommand.fromMap(m) as T:T==_g ?$ServerResponse.fromMap(m) as T:T==_h ?$ResponseOK.fromMap(m) as T:T==_i ?$ResponseError.fromMap(m) as T:T==_j ?$ArcaneServerSignature.fromMap(m) as T:throw _c();
