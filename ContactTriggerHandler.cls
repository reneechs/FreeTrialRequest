/*****************************************************************************************************************************************************
* @author           Renee Chua
* @description      This Apex Class is used to call TrialRequestClass if there is any changes to certain fields in Contact.
****************************************************************************************************************************************************/

public class ContactTriggerHandler  {
		
    /*********************************************************************************************
    *@Description : After update event on 'Contact' sObject trigger this method
    *********************************************************************************************/
    public override void afterUpdate() {
        if( !MEGATriggerFramework.isBypassed('CONTACT') && !MEGATriggerFramework.isBypassed('CONTACT_AFTER_UPDATE') && trigger.isUpdate && trigger.isAfter ){
            Map<Id, Contact> mapContactsTR			= new Map<Id, Contact>();
            List<Contact> lstOLDContacts			= Trigger.old;
            List<Contact> lstContacts				= Trigger.new;
			

            for(Contact c : lstContacts){
                for(Contact cOld : lstOLDContacts){
					if(c.Id == cOld.Id ){
				
						if(!String.isBlank(String.valueOf(c.TrialRequestTermsOfUseDate__c)) && c.trialRequestTermsOfUseDate__c != cOld.TrialRequestTermsOfUseDate__c)
							mapContactsTR.put(c.id, c);

					}
                }
            }

			try{
				// CREATE DEFAULT TRIAL REQUEST
				if(!mapContactsTR.isEmpty())
					TrialRequestClass.createDefaultTrialRequest(mapContactsTR);
			}
            catch(Exception e){ Trigger.New[0].addError('Trigger afterUpdate on Contact : Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage()); }
        }
    }
}