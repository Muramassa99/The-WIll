this is how motion will be done within the skill crafter 


bones involving  IK follow up 

and what they do 

between CC_Base_Waist and CC_Base_Spine01
we will allow a maximum of 35 degrees roll in each direction 
zero is in direction +Z for bone joint's coodinate system with a rotation on the ZX plane  rolling around the Y axis

between CC_Base_Spine01 and CC_Base_Spine02  
we will allow a maximum of 55 degrees roll in each direction 
zero is in direction +Z for bone joint's coodinate system with a rotation on the ZX plane  rolling around the Y axis

between CC_Base_Spine02 and  CC_Base_R_Clavicle 
we will allow maximum of -10 degrees  roll and +5 degrees 
zero is in the CC_Base_R_Clavicle coordinate system direction +Y , plane of rotation is on the YZ plane the roll is around the X axis of the CC_Base_R_Clavicle

between CC_Base_R_Clavicle and CC_Base_R_Upperarm
we will  allow maximum full 360 motion 
zero is in the CC_Base_R_Upperarm coordiante systems direction +Y, plane of rotation is on the YZ plane the roll is around the X axis of the CC_Base_R_Upperarm 

between CC_Base_R_Clavicle and CC_Base_R_Upperarm
we will allow zero to +180 degrees  of motion on the YX plane with roll on the Z axis  where zero is in the +Y direction  of the CC_Base_R_Upperarm coordiante system

CC_Base_R_UpperarmTwist01 is allowed  to rotate from zero to 90 degrees 
zero is in the CC_Base_R_UpperarmTwist01 coordinate system direction +X on the  XZ plane  with roll around the Y axis

between CC_Base_R_Upperarm and CC_Base_R_Forearm
we will allow from zero to +165 degrees of motion on the ZY plane , zero is in the +Y direction of the CC_Base_R_Forearm coordiante system with roll around the X axis

CC_Base_R_ForearmTwist01 is allowed  to rotate from zero to 90 degrees 
zero is in the CC_Base_R_ForearmTwist01 coordinate system direction +X on the  XZ plane  with roll around the Y axis

between CC_Base_R_Forearm and CC_Base_R_Hand
we wil allow from +90 degrees to -90 degrees  of motion  on the XY plane, zero is in the +Y direction of the CC_Base_R_Hand coordinate system
 with roll  around the Z axis.





between CC_Base_Spine02 and  CC_Base_L_Clavicle 
we will allow maximum of -10 degrees and +5 degrees 
zero is in the CC_Base_L_Clavicle coordinate system direction +Y , plane of rotation is on the YZ plane the roll is around the X axis of the CC_Base_L_Clavicle

between CC_Base_L_Clavicle and CC_Base_L_Upperarm
we will  allow maximum full 360 motion 
zero is in the CC_Base_L_Upperarm coordiante systems direction +Y, plane of rotation is on the YZ plane the roll is around the X axis of the CC_Base_L_Upperarm 

between CC_Base_L_Clavicle and CC_Base_L_Upperarm
we will allow zero to -180 degrees  of motion on the YX plane with roll on the Z axis  where zero is in the +Y direction  of the CC_Base_L_Upperarm coordiante system

CC_Base_L_UpperarmTwist01 is allowed  to rotate from zero to -90 degrees 
zero is in the CC_Base_L_UpperarmTwist01 coordinate system direction -X on the  XZ plane  with roll around the Y axis

between CC_Base_L_Upperarm and CC_Base_L_Forearm
we will allow from zero to +165 degrees of motion on the ZY plane , zero is in the +Y direction of the CC_Base_L_Forearm coordiante system with roll around the X axis

CC_Base_L_ForearmTwist01 is allowed  to rotate from zero to -90 degrees 
zero is in the CC_Base_L_ForearmTwist01 coordinate system direction -X on the  XZ plane  with roll around the Y axis
CC_Base_L_Forearm and CC_Base_L_Hand
between 
we wil allow from +90 degrees to -90 degrees  of motion  on the XY plane, zero is in the +Y direction of the CC_Base_L_Hand coordinate system
 with roll  around the Z axis.


for finger bones 

CC_Base_L_Thumb1/2/3
CC_Base_L_Index1/2/3
CC_Base_L_Mid1/2/3
CC_Base_L_Ring1/2/3
CC_Base_L_Pinky1/2/3
CC_Base_R_Thumb1/2/3
CC_Base_R_Index1/2/3
CC_Base_R_Mid1/2/3
CC_Base_R_Ring1/2/3
CC_Base_R_Pinky1/2/3

the plane of motion will be the YX plane with roll on the Z axis for each individual bone segment  and it's own coordinate system  




authority for the skill crafter will follow authority order in the scheleton system  of the model. meaning IK will folow proper parent child relationships

solving based on above restrictions .
the end points  that derie movement for the IK system will branch in a left and right side system starting from CC_Base_Waist to CC_Base_L_Hand for left side
and  CC_Base_Waist to CC_Base_R_Hand for right side.

if a weapon is present in 
the weapon will controll the hand position 
the hand and subsequent child bones are controlled by the Contact Group logic

if a 2 handed settup is present  the contact group logic wil solve for each hand and adjusting the IK system for each respective side 

if a weapon is not preset in a hand 
the Ik system is being solved  based  on

(new)

a similar to the wepon orientation system but  locally done  between

with the equivalent of the grip axis  system but in stead of solving  the end caps  for the grip validation it will solve  the position  between 

the joint point coordinate system located  in 2 points 

CC_Base_L_Hand and CC_Base_L_Index1  as "hand orientation index1 Left"
and
CC_Base_L_Hand and CC_Base_L_Pinky1 as "hand orientation pinky1 Left"

tre resulting points  will solve an axis  and act as orientation points  equivalent  to Pommel and Tip 

where 
"hand orientation index1 Left" will be the empty hand equivalent of Tip 
and
"hand orientation pinky1 Left" will be the empty hand equivalent of Pommel

allowing the positioning of the empty hand in space using the same system as if we'd have a weapon in it  for the sole reason of allowing the unnocupied  hand to assist  in motion allowing more freedome when it comes to crafting skills via motion nodes


the additional 2 points  will need to be added  to the Space Cicle  as passing points  to allow the new hand points  to be selected  and usd  as we currently intend to use  pommel and tip 


this system will later allow proper dual wielding animation edditing  since it is a solid base to allow that  to happen 


to clarify in the case  of the  2 handed grip scenario main hand and off hand will be driven by the same pommel an tip  but solve individually 


the current  body-plane that is directing  the weapon tip position needs to be removed 

and in it's place we will be using  the current , allways working  weapon roll as the "pathing plane " for he weapon .

this will create 2 things  1
function  ahahahah
and 2  have propper edge alignment when it comes  to strikes . simple , easy. working . 