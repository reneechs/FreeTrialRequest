global class WSRestCalloutClass {
	// ################################################ WEBSERVICE RESULT JSON CONTAINER ################################################
	
	public class AutoToolsResponse {
		public String Env;
		public String User;
		public String Pwd;
		public String CommandLine;
		public String ProfileAssignment;
		public String DateTimeResult;
		public String Language;
		public String TypeExec;
		public String ChangePwd;
		public String Status;
		public String Method;
		public String Details;
		public String TimeStamp;
	}

	// Calling webservice using @invocable method in order to be called from process builder 
	@InvocableMethod(label='Invoke Post Callout')
	public static void invokemakepostcall(List <ID> EnvId, int Mtd){
		System.debug(LoggingLevel.Error,'##### EnvID ### '+ EnvId);
		makePostCallout(EnvId,Mtd);
	}

	
	    
	private static final set<String> SET_PROFILE_AUTHORIZE = new Set<String>{'System Administrator', 'System Admin', 'Hosting Team', 'Pre-Sales Team'};
	

	webservice static string makePostCallout(Id p1, Integer p2) {
		String sMsgAlert	= 'You don\'t have the rights to perform a request on the server. Please contact the Pre-sales or the Hosting Team.';
		List<User> lstUser	= [SELECT ProfileId FROM USER WHERE Profile.Name IN: SET_PROFILE_AUTHORIZE AND ProfileId =:UserInfo.getProfileId() LIMIT 1];
        if(lstUser.size() > 0){
		// ******************************************************* ATTRIBUTES **********************************************************
		Map<Integer,String> mapMethods		= new Map<Integer,String>{	1 => '/AutoToolsWebService/api/V1.0/Users/UpdateUserPassword',
											2 => '/AutoToolsWebService/api/V1.0/Users/UpdateUser', // creation
											3 => '/AutoToolsWebService/api/V1.0/Users/UpdateUser', // update
											4 => '/AutoToolsWebService/api/V1.0/Environments/UpdateEnvPassword',
											5 => '/AutoToolsWebService/api/V1.0/Environments/RequestReinitEnv',
																			

			List<TrialLogin__c> lstTL		= new List<TrialLogin__c>();
			List< Environment__c> lstME		= new List<Environment__c>();
			String sJsonBody;
			String sServer;
			String sEnv;
			String sUsr;
			sMsgAlert				= 'The request failed to get a respond from the server.';

			// *****************************************************************************************************************
			// Description : UpdateUserPassword && UpdateUser
			//******************************************************************************************************************

			if(p2 < 4 && p2 > 0){
				try{
					lstTL	= [SELECT  User__r.Name, CustomUserName__c,  Profile__r.Name, TrialRequest__r. Environment__r.Name, TrialRequest__r. Environment__r.Server__r.Name, 
						 TrialRequest__r. Environment__r.Server__r.Platform__c, TrialRequest__r.StartDate__c, TrialRequest__r.EndDate__c, Language__c, CommandLine__c, Email__c 
						FROM TrialLogin__c WHERE (ID =:p1 OR TrialRequest__c =:p1) ];
				}
				catch(QueryException e){
					System.debug('##### makePostCallout on TrialLogin__c ##### Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage());
				}
				sServer = 'https://' + lstTL[0].TrialRequest__r. Environment__r.Server__r.Name;
				// Method : UpdateUserPassword
				if(lstTL[0].TrialRequest__r. Environment__r.Server__r.Platform__c == 'Free Trial' || lstTL[0].TrialRequest__r. Environment__r.Server__r.Platform__c == 'POC' || lstTL[0].TrialRequest__r. Environment__r.Server__r.Platform__c == 'Project'){
					if(p2 == 1){
						sJsonBody = '{"InputUserList":[';
						for(TrialLogin__c tl : lstTL){
							sEnv = '"Env":"'+(tl.TrialRequest__r. Environment__r.Name != null ? tl.TrialRequest__r. Environment__r.Name : '')+'"';
							if(tl.CustomUserName__c != null)
								sUsr = '"User":"'+tl.CustomUserName__c+'"';
							else
								sUsr = '"User":"'+(tl. User__r.Name != null ? tl. User__r.Name : '')+'"';
							sJsonBody += '{' + s Env + ',' + s Usr + '},';
						}
					}
					// Method : UpdateUser
					else{
						String sCmdLine;
						String sPrf;
						String sLang;
						String sTypeExe;
						String sStartD;
						String sEndD;
						if(p2 == 2)
							sTypeExe	= '"TypeExec":"create"';
						else
							sTypeExe	= '"TypeExec":"update"';

						sJsonBody = '{"InputUserListDetailed":[';
						for(TrialLogin__c tl : lstTL){
							sEnv = '"Env":"'+(tl.TrialRequest__r. Environment__r.Name != null ? tl.TrialRequest__r. Environment__r.Name : '')+'"';
							if(tl.CustomUserName__c != null)
								sUsr = '"User":"'+tl.CustomUserName__c+'"';
							else
								sUsr = '"User":"'+(tl. User__r.Name != null ? tl. User__r.Name : '')+'"';
							sCmdLine = '"CommandLine":"'+(tl.CommandLine__c != null ? tl.CommandLine__c : '')+'"';
							sPrf = '"ProfileAssignment":"'+(tl. Profile__r.Name != null ? tl. Profile__r.Name : '')+'"';
							sLang	= '"Language":"'+(tl.Language__c != null ? tl.Language__c : '')+'"';
							sStartD	= '"StartDate":"'+(tl.TrialRequest__r.StartDate__c != null ? String.valueOf(tl.TrialRequest__r.StartDate__c)+ ' 00:00:00' : '')+'"';
							sEndD	= '"EndDate":"'+(tl.TrialRequest__r.EndDate__c != null ? String.valueOf(tl.TrialRequest__r.EndDate__c)+ ' 00:00:00' : '')+'"';
							sJsonBody += '{' + s Env + ',' + s Usr + ',' + sCmdLine + ',' + s Prf + ',' + sStartD + ',' + sEndD + ',' + sLang + ',' + sTypeExe + ',"ChangePwd":"0"},';
						}
					}
				sJsonBody.removeEndIgnoreCase(',');
				sJsonBody += ']}';
				}
				else{
					sJsonBody = null;
					sMsgAlert = 'You don\'t have the rights to perform a request on a server in use by customers (Platforms available are : Free Trial / POC / Project).';
				}
				System.debug('##### mapJsonBody  #####'+sJsonBody);
				System.debug('##### TrialLogin__c lstTL   #####'+lstTL+' ##### '+sServer);
			}
			// *****************************************************************************************************************
			// Description : UpdateEnvPassword && RequestReinitEnv
			//******************************************************************************************************************
		
			else if(p2 == 5 || p2 == 4){
				try{
					lstME = [ SELECT Name, Server__r.Name, Server__r.Platform__c, Password__c FROM  Environment__c WHERE (ID =:p1 OR Server__c =:p1) ];
				}
				catch(QueryException e){
					System.debug(LoggingLevel.error,'##### makePostCallout on  Environment__c ##### Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage());
				}

				if(lstME[0].Server__r.Platform__c == 'Free Trial' || lstME[0].Server__r.Platform__c == 'POC' || lstME[0].Server__r.Platform__c == 'Project'){
					sServer = 'https://' + lstME[0].Server__r.Name;
					sJsonBody = '{"InputEnvList":[';
					for( Environment__c me : lstME){
						sEnv = '"Env":"'+(me.Name != null ? me.Name : '')+'"';
						sJsonBody += '{' + s Env + '},';
					}
					sJsonBody.removeEndIgnoreCase(',');
					sJsonBody += ']}';
				}
				else{
					sJsonBody = null;
					sMsgAlert = 'You don\'t have the rights to perform a request on a server in use by customers (Platforms available are : Free Trial / POC / Project).';
				}
				System.debug(LoggingLevel.error,'##### mapJsonBody  #####'+sJsonBody);
				System.debug(LoggingLevel.error,'#####  Environment__c lstME   #####'+lstME+' ##### '+sServer);
			}

			
			// ******************************Send HTTPRequest and GET HTTPResponse *******************************************************************

			List<AutoToolsResponse> lstAtc = (sJsonBody != null ? senRequest(sJsonBody, sServer + mapMethods.get(p2)) : new List<AutoToolsResponse>());
			System.debug(LoggingLevel.error,'##### lstAtc  #####'+JSON.serializePretty(lstAtc, True));


			// ****************************** HANDLE ERROR MESSAGE && Store it into Content Notes for reference *****************************************************************

			if(lstAtc.size() > 0){

				Set<Id> setTLId = new Set<Id>();
				Set<Id> setMEId = new Set<Id>();

				List<ContentNote> lstNte = new List<ContentNote>();
				List<ContentDocumentLink> lstlnk = new List<ContentDocumentLink>();
				Boolean isTLUpd		= False;
				Boolean isMEUpd		= False;
				sMsgAlert = '';

				if(lstME.size() > 0){
					for(AutoToolsResponse atc : lstAtc){
						sMsgAlert += atc.Env + ': ' + atc.Details + '\n';
						for( Environment__c me : lstME){
							if(!setMEId.contains(me.Id) && me.Name != null & atc.Env == me.Name){
		
								ContentNote cnt = new ContentNote();
								cnt.Content = Blob.valueOf(JSON.serializePretty(atc).escapeHtml4());
								cnt.Title   = atc.Status + ' for ' + atc.Env + ': ' + atc.Details;
								lstNte.add(cnt);

								try{
									if(lstNte.size() > 0)
										insert lstNte;
								}
								catch(DMLException e){
									System.debug(LoggingLevel.error,'##### UPDATE Note failed ##### Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage());
								}

								ContentDocumentLink clnk = new ContentDocumentLink();
								clnk.LinkedEntityId = me.Id;
								clnk.ContentDocumentId = lstNte[0].Id;
								clnk.ShareType = 'I';
								lstlnk.add(clnk);

								System.debug(LoggingLevel.error,'Content Note****' + lstNte + ' ' + lstlnk);

								if(atc.Method == 'RequestReinitEnv' && (atc.Status == 'OK' ||(atc.Status == 'KO' && atc.DateTimeResult != null))) {
									Datetime dtSch = Datetime.valueOf(atc.DateTimeResult);
									me.ResetStartDate__c = dtSch;	
									me.IsResetAsked__c = True;									
									isMEUpd = true;
								}
								else if(atc.Status == 'KO' && atc.Method == 'ResultReinitEnv'){
									me.IsResetAsked__c = false;
									isMEUpd = true;
								}
								else if(atc.Method == 'UpdateEnvPassword' && atc.Status == 'OK'){
									me.Password__c = atc.Pwd;
									isMEUpd = true;
								}
								setMEId.add(me.Id);
							}
						}
					}
				}
				else if(lstTL.size() > 0){
					for(AutoToolsResponse atc : lstAtc){
						sMsgAlert += atc.Status + ' for ' + atc.Env + ': ' + atc.Details + '\n';
						for(TrialLogin__c tl : lstTL){
							if( !setTLId.contains(tl.Id) && tl.CustomUserName__c != null && atc.User == tl.CustomUserName__c ){

				
								ContentNote cnt = new ContentNote();
								cnt.Content = Blob.valueOf(JSON.serializePretty(atc).escapeHtml4());
								cnt.Title   = atc.Status + ' for ' + atc.Env + ': ' + atc.Details;
								lstNte.add(cnt);

								try{
									if(lstNte.size() > 0)
										insert lstNte;
								}
								catch(DMLException e){
									System.debug(LoggingLevel.error,'##### UPDATE Note failed ##### Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage());
								}

								ContentDocumentLink clnk = new ContentDocumentLink();
								clnk.LinkedEntityId = tl.Id;
								clnk.ContentDocumentId = lstNte[0].Id;
								clnk.ShareType = 'I';
								lstlnk.add(clnk);

								if(atc.Status == 'OK' && (atc.Method == 'UpdateUserPassword' || atc.Method == 'UpdateUser')){
									tl.Password__c = atc.Pwd;
									isTLUpd = true;
								}
								setTLId.add(tl.Id);
							}
						}
					}
				}

				try{
					if(lstNte.size() > 0)
						insert lstlnk;

					if(isTLUpd)
						update lstTL;

					if(isMEUpd)
						update lstME;
				}
				catch(DMLException e){
					System.debug(LoggingLevel.error,'##### UPDATE FAILED makePostCallout ##### Exception at line number = ' + e.getLineNumber() + ', Error message = ' + e.getMessage());
				}
			}
        }
        return sMsgAlert;
    }

	private static List<AutoToolsResponse> senRequest(String sReqBody, String sReqEndP) {
		List<AutoToolsResponse> lstAtc		= new List<AutoToolsResponse>();
		AutoToolsResponse sObjatc		= new AutoToolsResponse();
		Http http				= new Http();
		HttpRequest request			= new HttpRequest();
		HttpResponse response			= new HttpResponse();
		String sResp;

		// Build HTTPRequest URL
		request.setEndpoint(sReqEndP);
		request.setBody(sReqBody);
		request.setMethod('POST');
		request.setHeader('Content-Type', 'application/json;charset=UTF-8');
		request.setTimeout(120000); // Maximum Value
		System.debug(LoggingLevel.error,'##### request  #####'+request);

		if(!Test.isRunningTest())
			response = http.send(request);
		else
			response = WSRestCalloutHttpMockTest.respond(request);

		// Transform HTTPResponse from JSON format into "AutoToolsResponse" custom object
		sResp = response.getBody();
		System.debug(LoggingLevel.error,'##### sResp  #####'+sResp);

		if(sResp.startsWithIgnoreCase('{')){
			sObjatc = (AutoToolsResponse)System.JSON.deserialize(sResp, AutoToolsResponse.class);
			lstAtc.add(sObjatc);
		}
		else if(sResp.startsWithIgnoreCase('['))
			lstAtc = (List<AutoToolsResponse>)System.JSON.deserialize(sResp, List<AutoToolsResponse>.class);

		return lstAtc;
	}	
}
