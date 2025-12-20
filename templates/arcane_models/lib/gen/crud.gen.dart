// GENERATED – do not modify.
import "package:arcane_models/arcane_models.dart";
import "dart:core";
import "package:fire_crud/fire_crud.dart";
import "package:fire_api/fire_api.dart";

/// CRUD Extensions for User
extension XFCrudBase$User on User {
  /// Gets this document (self) live and returns a new instance of [User] representing the new data
  Future<User?> get() => getSelfRaw<User>();
  
  /// Gets this document (self) live and caches it for the next time, returns a new instance of [User] representing the new data
  Future<User?> getCached() => getCachedSelfRaw<User>();
  
  /// Shorthand for documentId! Gets this instance id
  String get userId => documentId!;
  
  
  
  
  
  /// Opens a self stream of [User] representing this document
  Stream<User?> stream() => streamSelfRaw<User>();
  
  /// Sets this [User] document to a new value
  Future<void> set(User to) => setSelfRaw<User>(to);
  
  /// Updates properties of this [User] with {"fieldName": VALUE, ...}
  Future<void> update(Map<String, dynamic> u) => updateSelfRaw<User>(u);
  
  /// Deletes this [User] document
  Future<void> delete() => deleteSelfRaw<User>();
  
  /// Sets this [User] document atomically by getting first then setting.
  Future<void> setAtomic(User Function(User?) txn) => setSelfAtomicRaw<User>(txn);
  
  /// Modifies properties of the [User] document (as a unique child) atomically.
  Future<void> modify({
    
    /// Replaces the value of [name] with a new value atomically.
    String? name,
    
    /// Removes the [name] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteName = false,
    
    /// Replaces the value of [email] with a new value atomically.
    String? email,
    
    /// Removes the [email] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteEmail = false,
    
    /// Replaces the value of [profileHash] with a new value atomically.
    String? profileHash,
    
    /// Removes the [profileHash] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteProfileHash = false,
    bool $z = false
  }) =>
    updateSelfRaw<User>({ 
      if(name != null) 'name': name,
      if(deleteName) 'name': FieldValue.delete(),
      if(email != null) 'email': email,
      if(deleteEmail) 'email': FieldValue.delete(),
      if(profileHash != null) 'profileHash': profileHash,
      if(deleteProfileHash) 'profileHash': FieldValue.delete()
    });
}
    
/// CRUD Extensions for (UNIQUE) User.UserSettings
extension XFCrudU$User$UserSettings on User {
  /// Gets the [UserSettings] document (as a unique child)
  Future<UserSettings?> getUserSettings() => getUnique<UserSettings>();
  
  /// Gets the [UserSettings] document (as a unique child) and caches it for the next time
  Future<UserSettings?> getUserSettingsCached() => getCachedUnique<UserSettings>();
  
  /// Sets the [UserSettings] document (as a unique child) to a new value
  Future<void> setUserSettings(UserSettings value) => setUnique<UserSettings>(value);
  
  /// Deletes the [UserSettings] document (as a unique child)
  Future<void> deleteUserSettings() => deleteUnique<UserSettings>();
  
  /// Streams the [UserSettings] document (as a unique child)
  Stream<UserSettings?> streamUserSettings() => streamUnique<UserSettings>(); 
  
  /// Updates properties of the [UserSettings] document (as a unique child) with {"fieldName": VALUE, ...}
  Future<void> updateUserSettings(Map<String, dynamic> updates) => updateUnique<UserSettings>(updates);
  
  /// Sets the [UserSettings] document (as a unique child) atomically by getting first then setting.
  Future<void> setUserSettingsAtomic(UserSettings Function(UserSettings?) txn) => setUniqueAtomic<UserSettings>(txn);
  
  /// Ensures that the [UserSettings] document (as a unique child) exists, if not it will be created with [or]
  Future<void> ensureUserSettingsExists(UserSettings or) => ensureExistsUnique<UserSettings>(or);
  
  /// Gets a model instance of [UserSettings] bound with the unique id that can be used to access child models
  /// without network io (unique child).
  UserSettings userSettingsModel() => modelUnique<UserSettings>();
  
  /// Modifies properties of the [UserSettings] document (as a unique child) atomically.
  Future<void> modifyUserSettings({
    
    /// Replaces the value of [themeMode] with a new value atomically.
    ThemeMode? themeMode,
    
    /// Removes the [themeMode] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteThemeMode = false,
    bool $z = false
  }) =>
    updateUnique<UserSettings>({ 
      if(themeMode != null) 'themeMode': themeMode.name,
      if(deleteThemeMode) 'themeMode': FieldValue.delete()
    });
} 


/// CRUD Extensions for UserSettings
/// Parent Model is [User]
extension XFCrudBase$UserSettings on UserSettings {
  /// Gets this document (self) live and returns a new instance of [UserSettings] representing the new data
  Future<UserSettings?> get() => getSelfRaw<UserSettings>();
  
  /// Gets this document (self) live and caches it for the next time, returns a new instance of [UserSettings] representing the new data
  Future<UserSettings?> getCached() => getCachedSelfRaw<UserSettings>();
  
  /// Shorthand for documentId! Gets this instance id
  String get userSettingsId => documentId!;
  
  User get parentUserModel => parentModel<User>();
  
  String get parentUserId => parentDocumentId!;
  
  /// Opens a self stream of [UserSettings] representing this document
  Stream<UserSettings?> stream() => streamSelfRaw<UserSettings>();
  
  /// Sets this [UserSettings] document to a new value
  Future<void> set(UserSettings to) => setSelfRaw<UserSettings>(to);
  
  /// Updates properties of this [UserSettings] with {"fieldName": VALUE, ...}
  Future<void> update(Map<String, dynamic> u) => updateSelfRaw<UserSettings>(u);
  
  /// Deletes this [UserSettings] document
  Future<void> delete() => deleteSelfRaw<UserSettings>();
  
  /// Sets this [UserSettings] document atomically by getting first then setting.
  Future<void> setAtomic(UserSettings Function(UserSettings?) txn) => setSelfAtomicRaw<UserSettings>(txn);
  
  /// Modifies properties of the [UserSettings] document (as a unique child) atomically.
  Future<void> modify({
    
    /// Replaces the value of [themeMode] with a new value atomically.
    ThemeMode? themeMode,
    
    /// Removes the [themeMode] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteThemeMode = false,
    bool $z = false
  }) =>
    updateSelfRaw<UserSettings>({ 
      if(themeMode != null) 'themeMode': themeMode.name,
      if(deleteThemeMode) 'themeMode': FieldValue.delete()
    });
}
    

/// CRUD Extensions for ServerCommand
extension XFCrudBase$ServerCommand on ServerCommand {
  /// Gets this document (self) live and returns a new instance of [ServerCommand] representing the new data
  Future<ServerCommand?> get() => getSelfRaw<ServerCommand>();
  
  /// Gets this document (self) live and caches it for the next time, returns a new instance of [ServerCommand] representing the new data
  Future<ServerCommand?> getCached() => getCachedSelfRaw<ServerCommand>();
  
  /// Shorthand for documentId! Gets this instance id
  String get serverCommandId => documentId!;
  
  
  
  
  
  /// Opens a self stream of [ServerCommand] representing this document
  Stream<ServerCommand?> stream() => streamSelfRaw<ServerCommand>();
  
  /// Sets this [ServerCommand] document to a new value
  Future<void> set(ServerCommand to) => setSelfRaw<ServerCommand>(to);
  
  /// Updates properties of this [ServerCommand] with {"fieldName": VALUE, ...}
  Future<void> update(Map<String, dynamic> u) => updateSelfRaw<ServerCommand>(u);
  
  /// Deletes this [ServerCommand] document
  Future<void> delete() => deleteSelfRaw<ServerCommand>();
  
  /// Sets this [ServerCommand] document atomically by getting first then setting.
  Future<void> setAtomic(ServerCommand Function(ServerCommand?) txn) => setSelfAtomicRaw<ServerCommand>(txn);
  
  /// Modifies properties of the [ServerCommand] document (as a unique child) atomically.
  Future<void> modify({
    
    /// Replaces the value of [user] with a new value atomically.
    String? user,
    
    /// Removes the [user] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteUser = false,
    bool $z = false
  }) =>
    updateSelfRaw<ServerCommand>({ 
      if(user != null) 'user': user,
      if(deleteUser) 'user': FieldValue.delete()
    });
}
    
/// CRUD Extensions for (UNIQUE) ServerCommand.ServerResponse
extension XFCrudU$ServerCommand$ServerResponse on ServerCommand {
  /// Gets the [ServerResponse] document (as a unique child)
  Future<ServerResponse?> getServerResponse() => getUnique<ServerResponse>();
  
  /// Gets the [ServerResponse] document (as a unique child) and caches it for the next time
  Future<ServerResponse?> getServerResponseCached() => getCachedUnique<ServerResponse>();
  
  /// Sets the [ServerResponse] document (as a unique child) to a new value
  Future<void> setServerResponse(ServerResponse value) => setUnique<ServerResponse>(value);
  
  /// Deletes the [ServerResponse] document (as a unique child)
  Future<void> deleteServerResponse() => deleteUnique<ServerResponse>();
  
  /// Streams the [ServerResponse] document (as a unique child)
  Stream<ServerResponse?> streamServerResponse() => streamUnique<ServerResponse>(); 
  
  /// Updates properties of the [ServerResponse] document (as a unique child) with {"fieldName": VALUE, ...}
  Future<void> updateServerResponse(Map<String, dynamic> updates) => updateUnique<ServerResponse>(updates);
  
  /// Sets the [ServerResponse] document (as a unique child) atomically by getting first then setting.
  Future<void> setServerResponseAtomic(ServerResponse Function(ServerResponse?) txn) => setUniqueAtomic<ServerResponse>(txn);
  
  /// Ensures that the [ServerResponse] document (as a unique child) exists, if not it will be created with [or]
  Future<void> ensureServerResponseExists(ServerResponse or) => ensureExistsUnique<ServerResponse>(or);
  
  /// Gets a model instance of [ServerResponse] bound with the unique id that can be used to access child models
  /// without network io (unique child).
  ServerResponse serverResponseModel() => modelUnique<ServerResponse>();
  
  /// Modifies properties of the [ServerResponse] document (as a unique child) atomically.
  Future<void> modifyServerResponse({
    
    /// Replaces the value of [user] with a new value atomically.
    String? user,
    
    /// Removes the [user] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteUser = false,
    bool $z = false
  }) =>
    updateUnique<ServerResponse>({ 
      if(user != null) 'user': user,
      if(deleteUser) 'user': FieldValue.delete()
    });
} 


/// CRUD Extensions for ServerResponse
/// Parent Model is [ServerCommand]
extension XFCrudBase$ServerResponse on ServerResponse {
  /// Gets this document (self) live and returns a new instance of [ServerResponse] representing the new data
  Future<ServerResponse?> get() => getSelfRaw<ServerResponse>();
  
  /// Gets this document (self) live and caches it for the next time, returns a new instance of [ServerResponse] representing the new data
  Future<ServerResponse?> getCached() => getCachedSelfRaw<ServerResponse>();
  
  /// Shorthand for documentId! Gets this instance id
  String get serverResponseId => documentId!;
  
  ServerCommand get parentServerCommandModel => parentModel<ServerCommand>();
  
  String get parentServerCommandId => parentDocumentId!;
  
  /// Opens a self stream of [ServerResponse] representing this document
  Stream<ServerResponse?> stream() => streamSelfRaw<ServerResponse>();
  
  /// Sets this [ServerResponse] document to a new value
  Future<void> set(ServerResponse to) => setSelfRaw<ServerResponse>(to);
  
  /// Updates properties of this [ServerResponse] with {"fieldName": VALUE, ...}
  Future<void> update(Map<String, dynamic> u) => updateSelfRaw<ServerResponse>(u);
  
  /// Deletes this [ServerResponse] document
  Future<void> delete() => deleteSelfRaw<ServerResponse>();
  
  /// Sets this [ServerResponse] document atomically by getting first then setting.
  Future<void> setAtomic(ServerResponse Function(ServerResponse?) txn) => setSelfAtomicRaw<ServerResponse>(txn);
  
  /// Modifies properties of the [ServerResponse] document (as a unique child) atomically.
  Future<void> modify({
    
    /// Replaces the value of [user] with a new value atomically.
    String? user,
    
    /// Removes the [user] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteUser = false,
    bool $z = false
  }) =>
    updateSelfRaw<ServerResponse>({ 
      if(user != null) 'user': user,
      if(deleteUser) 'user': FieldValue.delete()
    });
}
    

/// Root CRUD Extensions for RootFireCrud
extension XFCrudRoot$User on RootFireCrud {
  /// Counts the number of [User] in the collection optionally filtered by [query]
  Future<int> countUsers([CollectionReference Function(CollectionReference ref)? query]) => $count<User>(query);
  
  /// Gets all [User] in the collection optionally filtered by [query]
  Future<List<User>> getUsers([CollectionReference Function(CollectionReference ref)? query]) => getAll<User>(query);
  
  /// Gets a document page starting at the beginning of the collection. Returns a [ModelPage<User>] that contains the models and nextPage method to get the next page
  Future<ModelPage<User>?> paginateUsers({int pageSize = 50, bool reversed = false, CollectionReference Function(CollectionReference ref)? query}) => paginate<User>(pageSize: pageSize, reversed: reversed, query: query);
  
  /// Deletes all [User] in the collection optionally filtered by [query]
  Future<void> deleteAllUsers([CollectionReference Function(CollectionReference ref)? query]) => deleteAll<User>(query);
  
  /// Opens a stream of all [User] in the collection optionally filtered by [query]
  Stream<List<User>> streamUsers([CollectionReference Function(CollectionReference ref)? query]) => streamAll<User>(query);
  
  /// Sets the [User] document with [id] to a new value
  Future<void> setUser(String id, User value) => $set<User>(id, value);
  
  /// Gets the [User] document with [id]
  Future<User?> getUser(String id) => $get<User>(id);
  
  /// Gets the [User] document with [id] and caches it for the next time
  Future<User?> getUserCached(String id) => getCached<User>(id);
  
  /// Updates properties of the [User] document with [id] with {"fieldName": VALUE, ...}
  Future<void> updateUser(String id, Map<String, dynamic> updates) => $update<User>(id, updates);
  
  /// Opens a stream of the [User] document with [id]
  Stream<User?> streamUser(String id) => $stream<User>(id);
  
  /// Deletes the [User] document with [id]
  Future<void> deleteUser(String id) => $delete<User>(id);
  
  /// Adds a new [User] document with a new id and returns the created model with the id set
  Future<User> addUser(User value, {bool useULID = false}) => $add<User>(value, useULID: useULID);
  
  /// Sets the [User] document with [id] atomically by getting first then setting.
  Future<void> setUserAtomic(String id, User Function(User?) txn) => $setAtomic<User>(id, txn);
  
  /// Ensures that the [User] document with [id] exists, if not it will be created with [or]
  Future<void> ensureUserExists(String id, User or) => $ensureExists<User>(id, or);
  
  /// Gets a model instance of [User] bound with [id] that can be used to access child models 
  /// without network io.
  User userModel(String id) => $model<User>(id);
  
  /// Modifies properties of the [User] document with [id] atomically.
  Future<void> modifyUser({
    required String id,
    
    /// Replaces the value of [name] with a new value atomically.
    String? name,
    
    /// Removes the [name] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteName = false,
    
    /// Replaces the value of [email] with a new value atomically.
    String? email,
    
    /// Removes the [email] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteEmail = false,
    
    /// Replaces the value of [profileHash] with a new value atomically.
    String? profileHash,
    
    /// Removes the [profileHash] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteProfileHash = false,
    bool $z = false
  }) =>
    $update<User>(id, { 
      if(name != null) 'name': name,
      if(deleteName) 'name': FieldValue.delete(),
      if(email != null) 'email': email,
      if(deleteEmail) 'email': FieldValue.delete(),
      if(profileHash != null) 'profileHash': profileHash,
      if(deleteProfileHash) 'profileHash': FieldValue.delete()
    });
}
    

/// Root CRUD Extensions for RootFireCrud
extension XFCrudRoot$ServerCommand on RootFireCrud {
  /// Counts the number of [ServerCommand] in the collection optionally filtered by [query]
  Future<int> countServerCommands([CollectionReference Function(CollectionReference ref)? query]) => $count<ServerCommand>(query);
  
  /// Gets all [ServerCommand] in the collection optionally filtered by [query]
  Future<List<ServerCommand>> getServerCommands([CollectionReference Function(CollectionReference ref)? query]) => getAll<ServerCommand>(query);
  
  /// Gets a document page starting at the beginning of the collection. Returns a [ModelPage<ServerCommand>] that contains the models and nextPage method to get the next page
  Future<ModelPage<ServerCommand>?> paginateServerCommands({int pageSize = 50, bool reversed = false, CollectionReference Function(CollectionReference ref)? query}) => paginate<ServerCommand>(pageSize: pageSize, reversed: reversed, query: query);
  
  /// Deletes all [ServerCommand] in the collection optionally filtered by [query]
  Future<void> deleteAllServerCommands([CollectionReference Function(CollectionReference ref)? query]) => deleteAll<ServerCommand>(query);
  
  /// Opens a stream of all [ServerCommand] in the collection optionally filtered by [query]
  Stream<List<ServerCommand>> streamServerCommands([CollectionReference Function(CollectionReference ref)? query]) => streamAll<ServerCommand>(query);
  
  /// Sets the [ServerCommand] document with [id] to a new value
  Future<void> setServerCommand(String id, ServerCommand value) => $set<ServerCommand>(id, value);
  
  /// Gets the [ServerCommand] document with [id]
  Future<ServerCommand?> getServerCommand(String id) => $get<ServerCommand>(id);
  
  /// Gets the [ServerCommand] document with [id] and caches it for the next time
  Future<ServerCommand?> getServerCommandCached(String id) => getCached<ServerCommand>(id);
  
  /// Updates properties of the [ServerCommand] document with [id] with {"fieldName": VALUE, ...}
  Future<void> updateServerCommand(String id, Map<String, dynamic> updates) => $update<ServerCommand>(id, updates);
  
  /// Opens a stream of the [ServerCommand] document with [id]
  Stream<ServerCommand?> streamServerCommand(String id) => $stream<ServerCommand>(id);
  
  /// Deletes the [ServerCommand] document with [id]
  Future<void> deleteServerCommand(String id) => $delete<ServerCommand>(id);
  
  /// Adds a new [ServerCommand] document with a new id and returns the created model with the id set
  Future<ServerCommand> addServerCommand(ServerCommand value, {bool useULID = false}) => $add<ServerCommand>(value, useULID: useULID);
  
  /// Sets the [ServerCommand] document with [id] atomically by getting first then setting.
  Future<void> setServerCommandAtomic(String id, ServerCommand Function(ServerCommand?) txn) => $setAtomic<ServerCommand>(id, txn);
  
  /// Ensures that the [ServerCommand] document with [id] exists, if not it will be created with [or]
  Future<void> ensureServerCommandExists(String id, ServerCommand or) => $ensureExists<ServerCommand>(id, or);
  
  /// Gets a model instance of [ServerCommand] bound with [id] that can be used to access child models 
  /// without network io.
  ServerCommand serverCommandModel(String id) => $model<ServerCommand>(id);
  
  /// Modifies properties of the [ServerCommand] document with [id] atomically.
  Future<void> modifyServerCommand({
    required String id,
    
    /// Replaces the value of [user] with a new value atomically.
    String? user,
    
    /// Removes the [user] field from the document atomically using FieldValue.delete(). See https://cloud.google.com/firestore/docs/manage-data/delete-data#fields
    bool deleteUser = false,
    bool $z = false
  }) =>
    $update<ServerCommand>(id, { 
      if(user != null) 'user': user,
      if(deleteUser) 'user': FieldValue.delete()
    });
}
    
