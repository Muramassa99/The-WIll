# Additional root-assigned full reads

## ID42 - Skill Crafter Implementation Stages 2026-04-24.md
FULL1-346. CreatedApr24,modifiedApr27; embeddedtitleApr24. Stagedimplementation spec overriding older roughrig wording16; not a completion log. This is direct documentary evidence for geometric hand-center construction even though word triangulation is not present.

- Lines20-22 Contact Group includes hand bones/finger bones/HAND SURFACE CONTACT PATCH plus weapon grip contact patch; they act together.
- Lines39-40 and174 root spelled LR_BoneRoot in oldertext; this differs from current RL_BoneRoot and must not override activecoordinateauthority.
- Lines50-61 occupied chain weaponframe -> rigidweapon -> ContactGroup -> wrist -> forearm/elbow/upperarm/clavicle/limitedspine.
- Lines70-76 both hands solve against ONEsharedrigidweapon, separate hand-to-weapon lanes; sharedweapon may yield to restore supportcontactbeforeclamp. Latest accepted Roll has narrower permissions; historical broadmovement permission is not blanketrollpermission.
- Lines90-104 exact LEFT anatomicalcenter law: F=CC_Base_L_Forearm,H=CC_Base_L_Hand,I=CC_Base_L_Index1,P=CC_Base_L_Pinky1. H/I/P define hand plane; I-P width; altitude from H to I-P gives palm-center/contact-center direction; F-H wristbackapproach; H+forearmhandjoint localzero; altitudepoint becomes axialcenter.
- Lines106-113 mirrored right IDs CC_Base_R_Forearm,CC_Base_R_Hand,CC_Base_R_Index1,CC_Base_R_Pinky1. This proves three handpoints are used to DERIVE a plane/center, not just two points. It does NOT specify three independent skin contact constraints.
- Scope caveat: heading86 explicitly Empty-Hand Surrogate Truth. Occupiedframe80-84 weaponattached. Need separate V1source/screenshot to show originallyoccupieduse; do not conflate lateremptyhandsurrogate description withcompleteoccupied palmclearance.
- Lines122-138 coupling: alreadyseated doesnothing126, reverse/side swaps seatrelationships; bowstringreusefuture138. Normal/reverse one-hand/two-hand unifiedstate164/267; generatedgripswap aroundcontactseat279.
- Stage3deliverables229-235 independently restate forearm/hand/indexroot/pinkyrootderived frames. Fullskincollision required149 but no measuredskin implementation proof.

## ID44 - Skill Crafter TODO 2026-04-21.md
FULL1-203. CreatedApr21,modifiedApr24; older planning notes deferred tocanonicalnewerwording17. Lines19-40 explicitly currentcode snapshot: motionnodes storetip/pommel/orientation/roll/axialoffset/gripseatslide/bodysupport/gripstyle/twohandstate. Gripgeometry construction unspecified.
- Lines51-67 stabilization: controlsonlyownintendedresponsibility55, smoothinteraction57, no heavyrecompute/diskwrites58. Future stance/swap/dualwield requires stablebaseline67.
- Normal/reverse/onehand/twohand pernode intended69-91, not implementation proof.
- Runtime legality on equipmentchange96 insteadpereveryframe, preserve authoredtruth95-113.
- Dualwieldplanned132-137; sameweaponindependentpage survivespairedmissing.
- Baseline defaultmeleeright1H150-151,shieldleft153,rangedleft155,magicright2H157-158; explicitnotfinalrestrictions160.
- No bone IDs, triangle/altitudelaw, measuredskin, or triangulationimplementation.

## ID45 - Skill Crafter Unified Implementation TODO 2026-04-30.md
FULL1-986 across1-275,276-550,551-795,796-986. CreatedApr30,modifiedAug30; contains April30implementationclaims,May3parkedwork,Aug29futurehandling,Aug30audit. Supersedes olderTODO onconflict7; still historical/currentmixed rather than blanketnewauthority.
- Lines26-28 foundation rigidtip/pommel, gripbridges frozenhandorientation; no palmskin fitting claim.
- Lines89-97 IMPLEMENTEDbodyproxygeneration fromloadedmeshBOUNDS+stable CC_Base naming, inflated5mm, oldhand-authoredfallback; weaponproxiesStage2displaycells, notdigitcontactskin.
- Lines118-139 pose/pathclearanceandtip/pommel legality; pathBezierfullclampfuture139. Structured collision usesproxies.
- Lines145-168 retarget pivotstorednormalized, geometrygrippositionused167, orientationseparate151. These are motionintentdefinitions nottriangularpalmoffset.
- Lines193-220 runtimeeffectivecopy; unavailabletwohanddegradation; generatedhand-swapbridges, savedauthoredchainunchanged.
- Lines228-236 IMPLEMENTEDtwisthelpers: skeletonupperarm/forearmtwistdetect230, requestedcontactframetwistmeasure231, distribute232, handbasisweaponcontactaxis/no-rollwrist233, cachedbaseline234, normalreversehand-Ztiprelation236.
- Lines244-253 guardrails mark reversetwohandunsupported250. This is historicalimplementation limitation, conflictingwithbroaderdirection-neutral combinations requirement, not a reason to narrowfuturegeometry.
- Lines365-397 Aug30stateaudit carefullydifferent importedIdle/2HandIdle vsidle_combat/idle_noncombat vsoffhand_free; runtimeincompleteness391-395parkedseparatefromgrip397.
- Lines531-558 mesh-derivedclearanceadaptation withstableboneIDs; includesHANDStarget548 though earlierimplementedlist92 omittedhands. No exacthand-bone IDs supplied beyond CC_Base contract.
- Lines763-793 rereadolderfourcombateditorfiles Apr30; recoveredStage1geometry/mass/grip/handling785; thisdoesnotrestateoriginaltrianglecenter algorithm.
- Lines841 saysitems1-15implemented; thereforethisis reportedimplementationhistory, not independentproof allbehaviorcorrecttoday.
- Lines851-870 May3 upperarmrollcontinuous/postsolvebias parked: weaponcontacttruthwins869. Latest accepted weaponRoll scope narrower.
- Lines876-896 Aug30 futureWIP roles. Currentexplicit executionpaths right_primary,left_primary,right_support,left_support883. Sharedlowlevelgeometryallowedwithexplicitindependentlytunablepolicy. Eitherhandranged893; melee894,rangedmagic895,shield896combinationsparked.
- Lines904-923 immutableCOM; one-wayintrinsicmass->TipPommel/Handlemode->activegripseats->handling; runtimegriprebase notsecondCOM. Named WeaponRootOrigin splitfuture WeaponGeometryOrigin/WeaponEquipRootOrigin/PrimaryGripMountOrigin; BakedProfile.center_of_mass retainedcompatibility.
- Lines925-941 futurebalancehypothesis leveragedistancebetweenTWOhandcontacts affectsvelocity. This is physics/handling multi-contact geometry, notthreepoint palmclearance.
- Lines943-969 futureUndoRedo notactivegripwork.
- Lines971-980 recordsprovenliveWIPwipe fromisolatedcloneatdefaultsavepath; diagnosticimmutabledataandexplicitnonlivepathsrequired980. Productionloadfailureprotectionstillfuture984-986.

Conclusion for theseadditionalreads: ID42 is clear hand-bone triangle/altitude construction evidence. It is distinct from (a) number of allowed seat-translation directions, (b) mesh triangulation, and (c) three independent skin-contact constraints. None of threefulltexts proves three independent measured palm contacts were implemented. Sourceimplementation/history tracing remains necessary to determine lost or preserved functionality.
