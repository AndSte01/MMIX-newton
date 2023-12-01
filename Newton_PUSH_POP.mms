% UTF-8

% Newton.mms - Newton Verfahren
%
% ©Andreas Steger (https://github.com/AndSte01), 2023
%
% In dieser Datei wird ein 2D Newton Verfahren implementiert mit welchem Nullstellen
% polynomialer Funktionen vierten Grades berechnet werden können (weitere Informationen
% siehe https://de.wikipedia.org/wiki/Newtonverfahren). Die Berechnung der benötigten
% Ableitung wird mit einem einfachen Zweipunkt Verfahren implementiert.
%
% In dieser Version wird außerdem die integrierte Stack Funktionalität der MMIX mittels
% der Befehle PUSH und POP genutzt
%
% Dieses Programm entstand im Rahmen der Kleingruppen-Übungen im Fach 'Grundlagen der
% modernen Informationstechnologie 1' im Wintersemester 2023/2024

% Einstellen des Encodings:
%    Options -> Encoding -> UTF-8
% Hinweis Der Puffer des Assemblers muss auf mindestens 100 erhöht werden:
%    Options -> Assembler -> Buffer Size

% Setzten der Aktuellen Position auf das Datensegment
% Dort können Daten gespeichert werden (hence the name)
			LOC Data_Segment

% Speichern der aktuellen Position in einem Globalen Register mit dem Label data
% Erinnerung: Wir haben diese Position gerade auf den Beginn des Datensegments gesetzt
% Hinweis: Globale Register sind Register welche (wichtige) Adressen im Hauptspeicher
% enthalten.
data		GREG @

% Setzen einiger Variablen im Hauptspeicher an jene zuvor ins globale Register ein-
% getragenen Stelle. Die Variablen werden dabei als Tetra im Hauptspeicher, in der 
% gegebenen Reihenfolge hinterlegt.
			TETRA	-1,3,2,-4,1	% Parameter der Funktion (als Ganzzahl)
			TETRA	20			% Maximale Zahl der Iterationen (da Newton Verfahren sehr
								% schnell konvergieren (wenn sie konvergieren) muss diese
								% Zahl nicht sonderlich groß sein, Ganzzahl)
			OCTA 	-1.00		% Initialwert (Start der Suche, Gleitkommazahl)
			OCTA	0.015625	% Schrittweite (Gleitkommazahl)
% Achtung: Die Gleitkommawerte die statisch zugewiesen werden müssen exakt dargestellt
% werden können (sprich eine Summe aus zweier Potenzen sein z. B. 2^-1+2^-3=0.625)
% Hinweise: Die Nullstellen mit der gegebenen Parametrisierung liegen bei ca. -1.3088749,
% 0.326637, 0.7161587, 3.2660789. Damit kann die Lösung geprüft werden.
% Startwerte zum Testen: -2, -1, 0.25, 0.375, 0.625, 1, 3, 4
% Extremstellen sind -0.7651302, 0.524821, 2.4903088 werden diese als Startwerte genommen
% ist schlechte Konvergenz zu erwarten (sprich es wird keine Nullstelle gefunden oder die
% Suche dauert sehr lange)
% Wird die Schrittweite zu groß gewählt wird das Verfahren instabil. Als (nicht näher
% Begründeter Richtwert) kann man 1/10 des kleinsten Abstandes zweier Extrema verwenden,
% besser noch kleiner. Wird die Schrittweite jedoch zu klein gewählt (nahe an der
% Maschinengenauigkeit) kann es zu Rundungsfehlern bei der Berechnung der nummerischen
% Ableitung kommen. Für weitere Details sei auf die Vorlesungen 'Numerische Methoden im
% Ingenieurwesen' oder 'Grundlagen der numerischen Strömungsmechanik' verwiesen.

% Setzen der Aktuellen Position (jetzt im Text Segment)
% Es wird hierbei einfach die Adresse 0x100 als Beginn des Programms gewählt.
% Hinweis: in der tatsächlichen Implementierung der MMIX sind Befehls- und Hauptspeicher
% in eine Einheit integriert. Die Trennung in der Vorlesung ergibt trotzdem Sinn, da die
% Bereiche für Programm (Text Segment) und variable Daten (Data Segment) durch das
% zuweisen verschiedener Adressbereiche getrennt werden (Siehe MMIX-Buch S.42,
% https://www.mmix.cs.hm.edu/doc/instructions.html#LOC). Man es sich durchaus auch wie
% physisch getrennte Speicher vorstellen. Dementsprechend beginnt unser Programmablauf
% an der Position 0x100, was im Bild der Vorlesung dem "Beginn" unseres Befehls-
% speichers gleichkommt.
			LOC #100

# Main-Programm
			PREFIX :Main	% Sorgt dafür das alle Labels mit Main beginnen
% definieren der Labels für Register

% Label für das Register mit aktuellem x und der Schrittweite
jmp_t_bk	IS $0	% Label für Register mit Rücksprungadressen
jmp_t_to	IS $1	% Label für Register mit der Adresse zu welcher Gesprungen werden soll
var_in_x	IS $2	% Register mit Rückgabewert x aus Iterationen
var_in_n	IS $3	% Register mit Rückgabewert n aus Iterationen
var_nmax	IS $3	% Label für Register mit Zahl der maximalen Iterationen
var_dx		IS $4	% Label für Register für den x-Wert
var_x		IS $5	% Label für Register für den x-Wert
var_a		IS $6	% Label für Register für a
var_b		IS $7	% Label für Register für b
var_c		IS $8	% Label für Register für c
var_d		IS $9	% Label für Register für d
var_e		IS $10	% Label für Register für e
% Weitere Temporäre Werte
var_n		IS $12	% Aktuelle Iteration


% Definieren des Main Programms (: vor Label sorgt dafür das kein Prefix verwendet wird)
:Main		GETA	jmp_t_to,:LdData		% Abrufen der Adresse des Unterprogramms
			GO		jmp_t_bk,jmp_t_to		% Springe in die Unterroutine zum Einlesen
											% der Funktionsparameter und sichern der
											% Rücksprungadresse. Hier ist die Verwendung
											% Eines einfachen GO besonders geschickt da:
											%  - Wir wissen das LdData keine weiteren
											%    Unterroutinen besitzt. Folglich gibt es
											%    keine Konflikte bei den Rücksprung-
											%    adressen.
											%    Erklärung: Man stelle sich ein Programm
											%     1 vor welches in eine Subroutine 2
											%     springt. Diese Subroutine springt dann
											%     wieder in eine weitere Subroutine 3:
											%     1 -> 2 -> 3. Würden alle diese Routinen
											%     ins gleiche Register ihre Rücksprung-
											%     adressen speichern dann käme es bei
											%     der Rückabwicklung zu Problemen
											%     3 -> 2 ! 1, da die Routine 2 nun nicht
											%     mehr weiß wie sie von sich zu 1 kommt
											%     (3 hat ja das Register verwendet um
											%     von sich zu 2 zurückzukommen, dasselbe
											%     Register wurde aber auch von 2
											%     verwendet um zu 1 zu kommen. Folglich
											%     kommt es zum Konflikt da beide unter-
											%     schiedliche Daten an gleicher Stelle
											%     speichern wollen)
											%  - Wir mit dieser Routine einiges an Daten
											%    einlesen wollen weshalb es uns viel Arbeit
											%    erspart wenn die Subroutine direkt mit den
											%    Registerwerten des Hauptprogramms arbeitet
			% Ausführen des Verfahrens
			PUSHJ	var_in_x,:DoIter		% Springen in die Iterationsroutine, dabei werden
											% alle Register vor var_in_x gesichert und danach
											% ein Sprung durchgeführt
			STOU	var_in_x,:data,40		% Speichern des Ergebnisses in den Hauptspeicher
			STO		var_in_n,:data,48		% Speichern der Zahl an Iterationen im Haupt-
											% speicher
			TRAP	0,:Halt,0				% Beende das Program mit einem
											% Rücksprung in das Betriebssystem


% Unterroutine zum Laden der Daten aus dem Hauptspeicher
:LdData		LDT		var_a,:data,0
			LDT		var_b,:data,4			% da hier ein Tetra geladen wird, müssen
											% die Adressen immer um 4 erhöht werden
			LDT		var_c,:data,8
			LDT 	var_d,:data,12
			LDT		var_e,:data,16
			LDT		var_nmax,:data,20
			% Umwandeln in Gleitkomma Zahlen
			FLOT	var_a,var_a
			FLOT	var_b,var_b
			FLOT	var_c,var_c
			FLOT	var_d,var_d
			FLOT	var_e,var_e
			% Laden weiterer Werte (schon in Gleitkommadarstellung)
			LDOU	var_x,:data,24			% Da wir hier einen Float laden darf kein
											% Vorzeichen berücksichtigt werden (daher
											% das U für Vorzeichenlos), außerdem haben
											% Floats die Länge eines Oktas weshalb hier
											% um 8 erhöht wurde
			LDOU	var_dx,:data,32
			GO		jmp_t_bk,jmp_t_bk,0		% Rücksprung

% Unterroutine zur Durchführung der Iterationen
			PREFIX :DoIter
% definieren der Labels für Register
var_ret_n	IS $0	% Label für Register mit n als Rückgabewert
var_ret_x	IS $1	% Label für Register mit Nullstelle als Rückgabewert
var_in_nmax	IS $0	% Label für 'Übergabe' Register mit Zahl der maximalen Iterationen
var_in_dx	IS $1	% Label für 'Übergabe' Register für den x-Wert
var_in_x	IS $2	% Label für 'Übergabe' Register für den x-Wert
var_in_a	IS $3	% Label für 'Übergabe' Register für a
var_in_b	IS $4	% Label für 'Übergabe' Register für b
var_in_c	IS $5	% Label für 'Übergabe' Register für c
var_in_d	IS $6	% Label für 'Übergabe' Register für d
var_in_e	IS $7	% Label für 'Übergabe' Register für e
var_t_rJ	IS $8	% Label für Register mit Sicherung der Rücksprungadresse
var_t_tgt	IS $9	% Label für Register mit unserem Ziel (wird zu 0 gesetzt)
var_t_n		IS $10	% Label für Register mit temporären Wert der aktuellen Iteration
var_t_f0	IS $11	% Label für Register mit zwischengespeichertem f(x) (aka. f0)
var_t_qfdf	IS $12	% Label für Register mit Quotienten aus f/df
var_t_ismax	IS $13	% Label für Register welches das Ergebnis der Prüfung enthält ob
					% n = n_max ist
var_t_istgt	IS $14	% Label für Register welches das Ergebnis der Prüfung enthält ob
					% f(x) = 0 ist und wir somit unser Ziel erreicht haben
var_in_f	IS $15	% Label für Register mit Ergebnis der Funktionsauswertung
var_out_x	IS $16	% Label für Register mit Parameter x von CalcF
var_out_a	IS $17	% Label für Register mit Parameter a von CalcF
var_out_b	IS $18	% Label für Register mit Parameter b von CalcF
var_out_c	IS $19	% Label für Register mit Parameter c von CalcF
var_out_d	IS $20	% Label für Register mit Parameter d von CalcF
var_out_e	IS $21	% Label für Register mit Parameter e von CalcF
var_in_df	IS $22	% Label für Register mit Ergebnis der Ableitungsberechnung
var_out_dx	IS $23	% Label für Register mit Parameter dx von CalcDF
var_out_f_1	IS $24	% Label für Register mit Parameter f_1 von CalcDF
var_out_f0	IS $25	% Label für Register mit Parameter f0 von CalcDF

:DoIter		GET		var_t_rJ,:rJ			% Sichern der Rücksprungadresse
			SETL	var_t_tgt,0				% Null setzten des Registers
			SETL	var_t_n,0				% Wir starten immer bei 0 Iterationen
			SET		var_out_a,var_in_a		% Kopieren des Wertes von var_in_x nach
											% var_out_x. Wird zu OR var_in_x,var_out_x
											% assembliert
			SET		var_out_b,var_in_b
			SET		var_out_c,var_in_c
			SET		var_out_d,var_in_d
			SET		var_out_e,var_in_e
			% Grund für diese Kopien ist da wir so die Parameter für einen späteren Aufruf
			% der Unterroutine ans Ende unserer verwendeten Register schieben können. Damit
			% werden wichtige Werte vor späteren Funktionsaufrufen mit dem Entsprechenden
			% PUSHJ Befehl gesichert (siehe MMIX Buch S. 112-118).
IterStep	CMPU	var_t_ismax,var_in_nmax,var_t_n	% Prüft ob wir die maximale Zahl an
													% Iterationen erreicht haben
			% Durchführen eines Sprungs zum Label IterBack falls wir die maximale Zahl
			% an Iterationen durchgeführt haben. Da wir kein P vorangestellt haben (also
			% BZ statt PBZ verwendet haben) geht die CPU davon aus das wir keinen Sprung
			% durchführen. Diese Hinweise and die Algorithmen zur Sprungvorhersage sind
			% eine wichtige Stellschraube für Optimierungen (Beispielsweise Implementierung
			% des Aufwind/upwind-Verfahrens mit Beträgen statt konditionaler Abfrage, siehe
			% auch Vorlesung 'Grundlagen der nummerischen Strömungsmechanik'). In unserem
			% Fall gehen wir stets davon aus das wir noch nicht die maximale Zahl an
			% Iterationen durchlaufen haben und wir folglich davon ausgehen nicht zu springen.
			% (Das ergibt auch Sinn da wir nur nach der letzten Iteration springen werden
			% und somit die Vorhersage nur einmal nicht stimmt)
			BZ		var_t_ismax,IterBack	% Für den Fall das wir die Maximale Zahl
											% an Iteration ausgeführt haben springen
											% wir weiter zum Label IterBack
			ADD		var_t_n,var_t_n,1		% Erhöhen des Iterationszählers um 1
			% Berechnen von f(x)
			SET		var_out_x,var_in_x		% Kopieren von x für nachfolgende Unterroutine
			PUSHJ	var_in_f,:CalcF			% Sprung in Unterroutine zum Berechnen von
											% f(x)
			% Prüfen ob wir bereits die Null erreicht haben
			FEQLE	var_t_istgt,var_in_f,var_t_tgt	% Wichtig ist hierbei ein Vergleich
													% mit ϵ (Maschinengenauigkeit) um
													% auch bei Rundungsfehlern die
													% Nullstelle erkennen zu können
													% Details siehe Vorlesung 'Numerische
													% Methoden im Ingenieurwesen'
			% Bedingter Sprung ans Ende falls wir fertig sind (hier erwarten wir ebenfalls
			% keinen Sprung, da wir davon ausgehen noch nicht am Ende zu sein)
			BNZ		var_t_istgt,IterBack
			% Zwischenspeichern des Wertes
			SET		var_t_f0,var_in_f		
			% Berechnen von f(x-dx)
			FSUB	var_out_x,var_in_x,var_in_dx	% Berechnen von x = x - dx
			PUSHJ	var_in_f,:CalcF			% Sprung in Unterroutine zum Berechnen von
											% f(x-dx)
			% Berechnen des Differenzen Quotienten
			SET		var_out_dx,var_in_dx	% Kopieren des Wertes für Parameterübergabe
			SET		var_out_f_1,var_in_f
			SET		var_out_f0,var_t_f0
			PUSHJ	var_in_df,:CalcDF		% Sprung in die Unterroutine zur Berechnung
											% von df
			% Hier wird auch deutlich warum wir die Register am weitesten hinten verwenden.
			% Da alle Register vor var_in_df gesichert werden (durch PUSHJ) bleiben die
			% Parameter der Funktion (var_out_a-var_out_e) vor der Berechnung der Ableitung
			% geschützt. Diese haben wir zuvor mühevoll in die Mitte unserer Register
			% kopieren müssen und können sie nun aber ganz entspannt immer wieder verwenden
			% (da sie ja geschützt sind). Damit ersparen wir uns einiges an Kopierarbeit
			% was unseren Algorithmus weiter beschleunigt.

			% Berechnen des nächsten x
			FDIV	var_t_qfdf,var_t_f0,var_in_df	% Berechnen von f/df
			FSUB	var_in_x,var_in_x,var_t_qfdf	% Berechnen des nächsten x
			% Da wir vorhin nicht vorzeitig zum Ende gesprungen sind ist davon auszugehen
			% das wir eine Weitere Iteration durchführen sollen
			JMP		IterStep

			% Wenn wir hier angelangt sind haben wir unser korrektes x berechnet (welches
			% in var_in_x steht)
IterBack	PUT		:rJ,var_t_rJ					% Wiederherstellen der Rücksprungadresse
			SET		var_ret_x,var_in_x				% Kopieren des berechneten x-Wertes für die Rückgabe
			SET		var_ret_n,var_t_n				% Kopieren der Anzahl an durchlaufenen Iterationen
													% für die Rückgabe
			POP		2,0								% Rückgängig machen des PUSH Befehls mit 2
													% Rückgabewerten (0-1) und Rücksprung zur
													% Adresse im Spezialregister rJ.


% Unterroutine zum Berechnen des Funktionswertes von f(x)
			PREFIX :CaclF
% definieren der Labels für Register
var_in_x	IS $0	% Label für 'Übergabe' Register für den x-Wert
var_in_a	IS $1	% Label für 'Übergabe' Register für a
var_in_b	IS $2	% Label für 'Übergabe' Register für b
var_in_c	IS $3	% Label für 'Übergabe' Register für c
var_in_d	IS $4	% Label für 'Übergabe' Register für d
var_in_e	IS $5	% Label für 'Übergabe' Register für e
var_ret_f	IS $6	% Label für Register mit Ergebnis
var_temp	IS $7	% Label für Register mit Zwischenergebnis

% Implementierung der Routine
:CalcF		SETL	var_ret_f,0						% f_0 = 0
			% Term a*x⁴:
			FMUL	var_temp,var_in_a,var_in_x	% fint_0 = a*x
			FMUL	var_temp,var_temp,var_in_x	% fint_1 = fint_0*x = a*x²
			FMUL	var_temp,var_temp,var_in_x	% fint_2 = fint_1*x = a*x³
			FMUL	var_temp,var_temp,var_in_x	% fint_3 = fint_2*x = a*x⁴
			FADD	var_ret_f,var_ret_f,var_temp % f_1 = fint + f_0 = fint = a*x⁴
			% Term b*x³
			FMUL	var_temp,var_in_b,var_in_x	% fint_0 = b*x
			FMUL	var_temp,var_temp,var_in_x	% fint_1 = fint_0*x = b*x²
			FMUL	var_temp,var_temp,var_in_x	% fint_2 = fint_1*x = b*x³
			FADD	var_ret_f,var_ret_f,var_temp % f_2 = f_1 + fint = a*x⁴ + b*x³
			% Term c*x²
			FMUL	var_temp,var_in_c,var_in_x	% fint_0 = c*x
			FMUL	var_temp,var_temp,var_in_x	% fint_1 = fint_0*x = c*x²
			FADD	var_ret_f,var_ret_f,var_temp % f_3 = f_2 + fint = a*x⁴ + b*x³ + c*x²
			% Term d*x
			FMUL	var_temp,var_in_d,var_in_x	% fint = d*x
			FADD	var_ret_f,var_ret_f,var_temp % f_4 = f_3 + fint = a*x⁴ + b*x³ + c*x²
												 %       + d*x
			% Term e
			FADD	var_ret_f,var_ret_f,var_in_e % f_4 = f_3 + e = a*x⁴ + b*x³ + c*x² + d*x
												 %       + e
			% Hinweis bei Rechnungen mit Gleitkommazahlen gibt es
			% keine immediate Varianten (also nur solche mit $X,$Y,$Z
			% und keine mit $X,$Y,Z)
			POP		7,0							% Rücksprung mit 7 Rückgabewerten
												% (0-6)

% Unterroutine zum Berechnen der Ableitung von f
			PREFIX :CalcDF
% Implementiert wird ein einfaches Zweipunktverfahren (Einfach der rückwärtsgewandte
% Differentialquotient)
%        f(x) - f(x-dx)
%   df = -------------
%             dx
% Außerdem wird der Wert von f(x) zurückgegeben
% definieren der Labels für Register
var_in_dx	IS $0	% Label für 'Übergabe' Register für den x-Wert
var_in_f_1	IS $1	% Label für 'Übergabe' Register für den Wert f(x-dx)
var_in_f0	IS $2	% Label für 'Übergabe' Register für den Wert f(x) 
var_ret_df	IS $3	% Label für Register mit Rückgabewert der Berechnung
var_t_N		IS $4	% Label für Register mit Nenner

:CalcDF		FSUB	var_t_N,var_in_f0,var_in_f_1	% Berechnen des Nenners
			FDIV	var_ret_df,var_t_N,var_in_dx	% Auswertung des Quotienten
													% (sehr rechenaufwendig)
													% Und speichern in Register für
													% Rückgabe
			POP		4,0								% Rücksprung mit 4 Rückgabewerten
													% (0-3)