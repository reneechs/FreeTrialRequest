/***********************************************************************************************************************************
* @author           Renee chua
* @description      This is a trigger for TrialRequest object
************************************************************************************************************************************/

trigger TrialRequestTrigger on TrialRequest (before insert, before update, after update) {
    TrialRequestTriggerHandler;
}