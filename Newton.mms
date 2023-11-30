% UTF-8

% Newton.mms - Newton Verfahren
%
% ©Andreas Steger (https://github.com/AndSte01), 2023
%
% In dieser Datei wird ein 2D Newton Verfahren implementiert mit welchem Nullstellen
% polynomialer Funktionen vierten Grades berechnet werden können (weitere Informationen
% siehe https://de.wikipedia.org/wiki/Newtonverfahren). Für die Berechnung der Benötigte
% Ableitung wird mit einem einfachen Zweipunkt Verfahren implementiert.
%
% Dieses Programm entstand im Rahmen der Kleingruppen-Übungen im Fach 'Grundlagen der
% modernen Informationstechnologie 1' im Wintersemester 2023/2024

% Einstellen des Encodings:
%    Options -> Encoding -> UTF-8
% Hinweis Der Puffer des Assemblers muss auf mindestens 100 erhöht werden:
%    Options -> Assembler -> Buffer Size

% Setzten der Atuellen Position auf das Datensegment
% Dort können Daten gespeichert werden (hence the name)
			LOC Data_Segment

% Speichern der aktuellen Position in einem Globalen Register mit dem Label data
% Erinnerung: Wir haben diese Position gerade auf den Beginn des Datensegments gesetzt
% Hinweis: Globale Register sind Register welche (wichtige) Adressen im Hauptspeicher
% enthalten.
data		GREG @

% setzen einiger Variablen im Hauptspeicher an die Stelle die zuvor ins Globale
% Register eingetragen wurde. Die Variablen werden dabei als Tetra in den Hauptspeicher
% eingetragen in der Reihenfolge wie sie unten stehen
			TETRA	-1,3,2,-4,1	% Parameter der Funktion (als Ganzzahl)
			TETRA	20			% Maximale Zahl der Iterationen (da Newton Verfahren sehr
								% schnell konvergieren (wenn sie konvergieren) muss diese
								% Zahl nicht sonderlich groß sein)
			OCTA 	1.00		% Initialwert (Start der Suche, Gleitkommazahl)
			OCTA	0.015625	% Schrittweite (Gleitkommazahl)
% Achtung: Die Gleitkommawerte die statisch zugewiesen werden müssen exakt dargestellt
% werden können (sprich eine Summe aus zweier Potenzen sein z. B. 2^-1+2^-3=0.625)
% Hinweise: Die Nullstellen mit der gegebenen Parametrisierung liegen bei ca. -1.3088749,
% 0.326637, 0.7161587, 3.2660789. Damit kann die Lösung geprüft werden.
% Extremstellen sind -0.7651302, 0.524821, 2.4903088 werden diese als Startwerte genommen
% ist schlechte Konvergenz zu erwarten (sprich es wird keine Nullstelle gefunden oder die
% Suche dauert sehr lange)
% Wird die Schrittweite zu groß gewählt wird das Verfahren instabil. Als (nicht näher
% Begründeter Richtwert) kann man 1/10 des kleinsten Abstandes zweier Extrema verwenden,
% besser noch kleiner. Wird die Schrittweite jedoch zu klein gewählt (nahe an der
% Maschinengenauigkeit) kann es zu Rundungsfehlern bei der Berechnung der nummerischen
% Ableitung kommen. Für weitere Details sei auf die Vorlesungen 'Numerische Methoden im
% Ingenieurwesen' oder 'Grundlagen der numerischen Strömungsmechanik' verwiesen.

% Definieren von Labels im Registerspeicher erleichtern uns lediglich die Arbeit
% im späteren Verlauf)

% Register für Rücksprungadressen
jmp_bk		IS $0	% Rücksprungadressen
jmp_bk1		IS $1	% Da wir uns derart viele Vorhalten, können wir auf einen
jmp_bk2		IS $2	% Stack verzichten (man kann aber schon erkennen das
jmp_bk3		IS $3	% dies eine unschöne Implementierung ist)
jmp_to		IS $4	% Adresse zu der Gesprungen werden soll

% Label für Register mit den Parametern unserer Kubischen Funktion. Die Funktion hat
% das folgende Aussehen: y = a*x³ + b*x² + c*x + d
var_a		IS $8
var_b		IS $9
var_c		IS $10
var_d		IS $11
var_e		IS $12

% Label für das Register mit aktuellem x und der Schrittweite
var_x		IS $16
var_x_l		IS $17	% x aus vorherigem Schritt
var_dx		IS $18

% Label für Register mit dem aktuellen Funktions-/Ableitungswert
var_f		IS $20
var_df		IS $21

% Weitere Labeln von Registern für den temporären Gebrauch
var_n_max	IS $22	% Maximale Zahl der Iterationen
var_n		IS $23	% Aktuelle Iteration
var_fx		IS $24	% Übergabewert des gewünschten x der Routine CalcF
var_fint	IS $25	% Für Interne Berechnung von CalcF
var_f_s		IS $26	% gesicherter Wert von f
var_qfdf	IS $27	% Quotient in CaclNextX
var_isclose	IS $28	% Wird zu 1 wenn wir das Ergebnis erreicht haben
var_isnmax	IS $29	% Wir haben die maximale Zahl an Iterationen erreicht
var_target	IS $30	% Wird zu 0 gesetzt



% Setzen der Aktuellen Position (jetzt im Text Segment)
% Es wird hierbei einfach die Adresse 0x100 als Beginn des Programs gewählt.
% Hinweis: in der tatsächlichen Implementierung der MMIX sind Befehls und Hauptspeicher
% in eine Einheit integriert. Die Trennung in der Vorlesung ergibt trotzdem Sinn, da die
% Bereiche für Programm (Text Segment) und variable Daten (Data Segment) durch das
% zuweisen verschiedener Adressbereiche getrennt werden (Siehe MMIX-Buch S.42,
% https://www.mmix.cs.hm.edu/doc/instructions.html#LOC) und man es sich auch wie physisch
% verschiedene Speicher vorstellen kann. Dementsprechend beginnt unser Programmablauf
% an der Position 0x100, was im Bild der Vorlesung dem "Beginn" unseres Befehls-
% speicher gleichkommt.
			LOC #100

% Definieren des Main Programs
Main		GETA	jmp_to,LdData			% Abrufen der Adresse des Unterprogramms
			GO		jmp_bk,jmp_to			% Springe in die Unterroutine zum Einlesen
											% der Funktionsparameter und sichern der
											% Rücksprungadresse.
			% Ausführen des Verfahrens
			GETA	jmp_to,DoIter			% Abrufen der Adresse
			GO		jmp_bk,jmp_to			% Ausführen des Sprungs
			STOU	var_x_l,data,40			% Speichern des Ergebnisses in den Hauptspeicher
			STO		var_n,data,48			% Speichern der Zahl an Iterationen im Haupt-
											% speicher
			TRAP	0,Halt,0				% Beende das Program mit einem
											% Rücksprung in das Betriebssystem

% Unterroutine zum Laden der Daten aus dem Hauptspeicher
LdData		SETL	var_target,0			% Wir wollen ja die 0 erreichen
			LDT		var_a,data,0
			LDT		var_b,data,4			% da hier ein Tetra geladen wird müssen
											% die Adressen immer um 4 erhöht werden
			LDT		var_c,data,8
			LDT 	var_d,data,12
			LDT		var_e,data,16
			SETL	var_n,0					% wir starten immer bei 0 Iterationen
			LDT		var_n_max,data,20
			% Umwandeln in Gleitkomma Zahlen
			FLOT	var_a,var_a
			FLOT	var_b,var_b
			FLOT	var_c,var_c
			FLOT	var_d,var_d
			FLOT	var_e,var_e
			% Laden weiterer Werte (schon in Gleitkommadarstellung)
			LDOU	var_x,data,24			% Da wir hier einen Float laden darf kein
											% Vorzeichen berücksichtigt werden (daher
											% das U für Vorzeichenlos) außerdem haben
											% Floats die Länge eines Oktas weshalb hier
											% um 8 erhöht wurde
			LDOU	var_dx,data,32
			GO		jmp_bk,jmp_bk,0			% Rücksprung

% Unterprogramm für die Iterationen
DoIter		CMPU	var_isnmax,var_n_max,var_n	% Prüft ob wir die maximale Zahl an
												% Iterationen erreicht haben
			BZ		var_isnmax,DoIterBack	% Für den Fall das wir die Maximale Zahl
											% an Iteration ausgeführt haben springen
											% wie weiter zum Label Back
			ADD		var_n,var_n,1			% Erhöhen des Iterationszählers um 1
			GETA	jmp_to,CalcNextX		% Vorbereiten der Iteration
			OR		jmp_bk1,jmp_bk,0		% Sichern der Rücksprungadresse
			GO		jmp_bk,jmp_to			% Sprung in die erste Iteration
			OR		jmp_bk,jmp_bk1,0		% Wiederherstellen der Rücksprungadresse
			% Berechnen ob wir nahe genug daran sind
			% Hier werden Werte recycled
			FEQLE	var_isclose,var_f_s,var_target	% Wichtig ist hierbei ein Vergleich
													% mit ϵ (Maschinengenauigkeit) um
													% auch bei Rundungsfehlern die
													% Nullstelle erkennen zu können
			% Ausführen eines bedingten Sprungs sollte var_isclose 0 sein
			% Besonders interessant ist hier das Vorangestellte P da man damit dem
			% Algorithmus zur Sprungvorhersage mitteilen kann das der Sprung mit
			% Wahrscheinlichkeit durchgeführt wird. Das ermöglicht zusätzliche
			% Optimierungen (eine korrekte Vorhersage ist schneller als eine falsche).
			% In diesem Fall gehen wir davon aus das wir noch weitere Iterationen durch-
			% führen müssen und somit einen Sprung erwarten. Nur im Fall das wir das
			% Ergebnis haben springen wir nicht, damit liegt unsere Vorhersage höchstens
			% einmal falsch was hinzunehmen ist.
			PBZ		var_isclose,DoIter
			
			% Wenn wir hier angelangt sind haben wir unser korrektes x berechnet (welches
			% in var_x_l steht
DoIterBack	GO		jmp_bk,jmp_bk,0		% Rücksprung ins Hauptprogramm



% Unterroutine zum Berechnen des nächsten Newton Schritts
% beschreibt var_x, var_qfdf
CalcNextX	OR		var_x_l,var_x,0			% Sichern des Vorherigen x
			GETA	jmp_to,CalcDF			% Abrufen der Adresse des Unterprogramms
			OR		jmp_bk2,jmp_bk,0		% Sichern der Rücksprungadresse
			GO		jmp_bk,jmp_to			% Springe in die Unterroutine
			OR		jmp_bk,jmp_bk2,0		% Wiederherstellen der Rücksprungadresse
			FDIV	var_qfdf,var_f_s,var_df	% Berechnen des Quotienten Wert von f(x)
											% wird uns schon von CalcDF geliefert
			FSUB	var_x,var_x,var_qfdf	% berechnen des nächsten Schritts
			GO		jmp_bk,jmp_bk,0			% Rücksprung


% Unterroutine zum Berechnen von f
% gewünschter x Wert wird dabei über var_fx übergeben
% Beschreibt var_fint, var_f
CalcF		SETL	var_f,0						% f_0 = 0
			% Term a*x⁴:
			FMUL	var_fint,var_a,var_fx		% fint_0 = a*x
			FMUL	var_fint,var_fint,var_fx	% fint_1 = fint_0*x = a*x²
			FMUL	var_fint,var_fint,var_fx	% fint_2 = fint_1*x = a*x³
			FMUL	var_fint,var_fint,var_fx	% fint_3 = fint_2*x = a*x⁴
			FADD	var_f,var_f,var_fint		% f_1 = fint + f_0 = fint = a*x⁴
			% Term b*x³
			FMUL	var_fint,var_b,var_fx		% fint_0 = b*x
			FMUL	var_fint,var_fint,var_fx	% fint_1 = fint_0*x = b*x²
			FMUL	var_fint,var_fint,var_fx	% fint_2 = fint_1*x = b*x³
			FADD	var_f,var_f,var_fint		% f_2 = f_1 + fint = a*x⁴ + b*x³
			% Term c*x²
			FMUL	var_fint,var_c,var_fx		% fint_0 = c*x
			FMUL	var_fint,var_fint,var_fx	% fint_1 = fint_0*x = c*x²
			FADD	var_f,var_f,var_fint		% f_3 = f_2 + fint = a*x⁴ + b*x³ + c*x²
			% Term d*x
			FMUL	var_fint,var_d,var_fx		% fint = d*x
			FADD	var_f,var_f,var_fint		% f_4 = f_3 + fint = a*x⁴ + b*x³ + c*x² + d*x
			% Term e
			FADD	var_f,var_f,var_e			% f_4 = f_3 + e = a*x⁴ + b*x³ + c*x² + d*x + e
			% Hinweis bei Rechnungen mit Gleitkommazahlen gibt es
			% keine immediate Varianten (also nur solche mit $X,$Y,$Z
			% und keine mit $X,$Y,Z
			GO		jmp_bk,jmp_bk,0			% Rücksprung


% Unterroutine zum Berechnen der Ableitung von f
% gewünschter x Wert wird dabei über var_x übergeben
% Implementiert wird ein einfaches Zweipunktverfahren (Einfach der rückwärtsgewandte
% Differentialquotient)
%        f(x) - f(x-dx)
%   df = -------------
%             dx
% beschreibt var_df, var_fx, var_f_s
CalcDF		SETL	var_df,0				% f_0 = 0
			OR		var_fx,var_x,0			% kopieren von x nach t1
											% hier währe alternativ auch SET var_fx,var_x
											% möglich der Assembler würde dies aber
											% wieder zu einem OR übersetzen
			GETA	jmp_to,CalcF			% Abrufen der Adresse des Unterprogramms
			OR		jmp_bk3,jmp_bk,0		% Sichern der Rücksprungaddresse
			GO		jmp_bk,jmp_to			% berechnet unsere var_f an der Stelle t1
			OR		var_f_s,var_f,0			% sichern des Wertes in t3
											% er ist an mehreren Stellen nützlich
			FSUB	var_fx,var_x,var_dx		% t1 = x-dx
			GO		jmp_bk,jmp_to			% Berechnen von f an einer weiteren Stelle
			% Berechnen des Differentialquotienten
			FSUB	var_fx,var_f_s,var_f		
			FDIV	var_df,var_fx,var_dx	% Auswertung des Quotienten (sehr rechenaufwendig)
			OR		jmp_bk,jmp_bk3,0		% Wiederherstellen der Rücksprungadresse
			GO		jmp_bk,jmp_bk,0			% Rücksprung