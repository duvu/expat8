/**
 * Copies the methods of per-domain method classes onto a store class so one
 * store object keeps the full interface while each domain lives in its own
 * module. Method classes must not use private (#) members: those are bound to
 * the declaring class.
 */
export function mixinMethods(StoreClass, ...methodClasses) {
  for (const methodClass of methodClasses) {
    for (const [name, descriptor] of Object.entries(Object.getOwnPropertyDescriptors(methodClass.prototype))) {
      if (name !== 'constructor') {
        Object.defineProperty(StoreClass.prototype, name, descriptor);
      }
    }
  }
}
