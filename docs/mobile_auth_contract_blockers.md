# Mobile Auth Contract Blockers

Status: Contract blockers cleared
Audit date: 2026-04-05
Workspace: `D:\mobileallclubs`

## Discovery Result

The source-of-truth contract is now explicit from the working web repo:

- `D:\agentallclubs — копия\src\pages\Login.jsx`
- `D:\agentallclubs — копия\src\context\AuthContext.jsx`
- `D:\agentallclubs — копия\src\services\onboardingService.js`
- `D:\agentallclubs — копия\src\pages\CreateClub.jsx`
- `D:\agentallclubs — копия\src\pages\VerifyEmail.jsx`

The following items are no longer missing:

1. real sign-in method
2. real current-user profile path
3. real gym resolution path
4. real owner/staff role source
5. real onboarding callable name and request body

## Exact Contracts Now Known

- Login: `signInWithEmailAndPassword`
- Register: `createUserWithEmailAndPassword`
- Password reset: `sendPasswordResetEmail`
- Verify email: `sendEmailVerification`
- User doc path: `users/{uid}`
- Gym resolution: `users/{uid}.gymId -> gyms/{gymId}/users/{uid} -> gyms/{gymId}`
- Role source: `users/{uid}.role` mirrored at `gyms/{gymId}/users/{uid}.role`
- Onboarding callable: `createGymAndUser`
- Onboarding payload: `gymData = { name, city, phone, firstName, lastName }`

## Remaining Blockers

There are no remaining contract-definition blockers.

Only runtime-safety or coverage blockers remain:

1. live `staff` path not yet exercised on Samsung
2. live `super_admin` path not yet exercised on Samsung
3. live unverified-email gate is now exercised, but actual email-confirm completion is still not exercised
4. local Android debug attach is still flaky because of the known `adb forward` issue
5. the test onboarding account and gym created during verification should be kept or cleaned up intentionally later

## Safe Conclusion

Mobile no longer needs guessed auth/bootstrap contracts.

The remaining decision is not discovery. It is whether to:

- keep moving with read-only feature work, or
- explicitly approve live production onboarding verification with a disposable account.
