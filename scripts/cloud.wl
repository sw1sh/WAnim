(* cloudConnect[envFile] connects to the Wolfram Cloud as the account an .env file names
   (WOLFRAM_CLOUD_USER, WOLFRAM_CLOUD_PASSWORD), and does nothing when already connected as it.
   The repository keeps two gitignored .env files at its root: .env for the cloud work of the
   builds, .env.publish for the account that owns the WolframInstitute publisher.  The password
   is never printed. *)

envValues[file_String] := Association @ StringCases[Import[file, "Text"],
    StartOfLine ~~ k : (WordCharacter | "_") .. ~~ "=" ~~ v : Except["\n"] ... :> k -> StringTrim[v, "\"" | "'" | Whitespace]];

cloudConnect[file_String] := Module[{env},
    $AllowInternet = True;
    If[! FileExistsQ[file], Print["FATAL: no ", file, " with WOLFRAM_CLOUD_USER and WOLFRAM_CLOUD_PASSWORD"]; Exit[1]];
    env = envValues[file];
    If[$CloudConnected && $WolframID === env["WOLFRAM_CLOUD_USER"], Return[$WolframID]];
    CloudConnect[env["WOLFRAM_CLOUD_USER"], env["WOLFRAM_CLOUD_PASSWORD"]];
    If[$WolframID =!= env["WOLFRAM_CLOUD_USER"], Print["FATAL: could not connect as ", env["WOLFRAM_CLOUD_USER"]]; Exit[1]];
    Print["connected as ", $WolframID];
    $WolframID];
