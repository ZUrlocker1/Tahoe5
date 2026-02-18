{ Tahoe5D.pas
  Simple five card video poker game in plain Turbo Pascal 4.0 for DOS
  Minimal language features to make it easier to port

 Done:
   -Defined card type
   -Initialize, shuffle and basic text dump routines
   -Deal a hand of cards
   -Evaluate a hand
   -Drawing of cards
   -Game loop to play multiple hands
   -Opening screen
   -Basic scoreboard, help screen
   -Cards drawn with boxes
   -Bets and balance
   -Scoring
   -Added some sound routines
 To Do:
  -look at the old Tahoe5w code and consider any simplifications
  -clean up some of the UX code from game logic
   -put scores and strings into an array
      -refactor drawing into its own routines - at least the hold status!
   -since the help screen otherwise wipes that out!
   -consider if any TechnoJock Toolkit code is useful to either
    improve the UX (with color, etc) or simplify code
}

{$R+  range checking on }

Program Tahoe;
uses Crt;

{ global declarations }
Type
     tCard = record
       rank : 1..13;    { Ace low to King }
       suit : 1..4;     { clubs, diamonds, hearts, spades }
       r: string[2];    { rank text e.g. 'A', '2'.. '10', 'J' etc }
       s: char;         { suit text e.g. 'C', 'D', 'H', 'S' }
     end;

     tRankCount = array [1..13] of integer; { so we can pass to isStraight }
     tDeck = array [1..52] of tCard;
     tHand = array [1..5] of tCard;

Var
     deck : tDeck;
     hand : tHand;
     top : integer;   { identifies next card to be dealt }
     i, bet, balance, score : integer;
     key : char;
     hold : array [1..5] of boolean;
     indexStr : string[3];
     soundOn : boolean;

Const
  C3 = 131; { Frequencies for musical notes }
  D3 = 147;
  E3 = 165;
  F3 = 175;
  G3 = 196;
  A3 = 220;
  B3 = 247;

  C4 = 262;
  D4 = 294;
  E4 = 330;
  F4 = 349;
  G4 = 392;
  A4 = 440;

  C5 = 523;
  D5 = 587;
  E5 = 659;
  F5 = 698;
  G5 = 784;
  A5 = 880;

  C6 = 1047;
  E6 = 1318;
  G6 = 1568;

{ Sound Routines }
procedure PlayNote(Frequency: integer; Duration: integer);
begin
  if SoundOn then     { check if user turned off sound }
  begin
    Sound(Frequency);
    Delay(Duration);
    NoSound;
  end;
end;

procedure StartingSound;
begin
  { A simple ascending arpeggio or chime sequence }
  PlayNote(C4, 100);
  PlayNote(E4, 100);
  PlayNote(G4, 100);
  PlayNote(C5, 150);
  Delay(50); { Small pause for effect }
end;

procedure LosingSound;
begin
  { A descending, slightly dissonant tone sequence }
  PlayNote(C4, 150);
  PlayNote(B3, 150);
  PlayNote(A3, 150);
  Delay(200); { Pause before a final low tone }
  PlayNote(G3, 300);
  Delay(50);
  NoSound;
end;

procedure WinningSound;
begin
  { A short, sharp ascending tone followed by a higher sustained tone }
  PlayNote(C5, 100);
  PlayNote(E5, 100);
  PlayNote(G5, 200);
  Delay(100);
  PlayNote(C6, 400);
  Delay(50);
  NoSound;
end;

procedure GreatWinningSound;
begin
  { A more complex, higher-pitched, and slightly longer sequence }
  PlayNote(E5, 100);
  PlayNote(G5, 100);
  PlayNote(C6, 150);
  PlayNote(E6, 200); { Even higher for impact }
  Delay(50);

  PlayNote(G6, 250);
  Delay(50);
  { A final flourish }
  PlayNote(C6, 100);
  PlayNote(G5, 100);
  PlayNote(E6, 300); { Return to a high, sustained tone }
  Delay(50);
  NoSound;
end;

procedure LoBeep;
begin
  PlayNote(c3, 60);  { Short, medium pitch }
end;

procedure HiBeep;
begin
  PlayNote(C4, 20); { Short, higher pitch }
end;

{ Generate a starting deck in order with text for rank, suit }
procedure initDeck(var d : tDeck);
var
    i, c, s : integer;
    sName : array[1..4] of char;
    rankStr : string[3];  { rank as a string }
    ch: char;
Begin
    sName[1] := chr(5);   { club }
    sName[2] := chr(4);   { diamond }
    sName[3] := chr(3);   { heart }
    sName[4] := chr(6);   { spade }
    for s := 1 to 4 do
     for i := 1 to 13 do
      begin
       c := i + (s-1)*13;   { calculate the card index only once }
       d[c].rank := i;      { cards go from A, 2..10, J, Q, K }
       d[c].suit := s;
       case i of
           1 : rankStr := 'A';
          11 : rankStr := 'J';
          12 : rankStr := 'Q';
          13 : rankStr := 'K';
       else
           Str(i, rankStr);  { convert 2..10 numbers to string }
       end;
       d[c].r := rankStr;
       d[c].s := sName[s];
      end;
end;

{ Shuffle initial deck using Fisher-Yates O(n) algorithm
  Swaps elements starting at the end with a random earlier element }
procedure shuffle (var d:tDeck);
var i, j: integer;
  temp : tCard;
begin
  Randomize;  { seed with clock }
  for i := 52 downto 2 do
  begin
    j := Random(i) + 1;  { random element less than current }
    temp := d[i];
    d[i] := d[j];  { swap them }
    d[j] := temp;
  end;
end;

{ check if there is a straight }
{ Note: TP requires a named type rather than array[1..13] of integer }
function isStraight(rankCount: tRankCount): boolean;
var i, sequence : integer;
begin
    isStraight := false;
    sequence := 0;
    i := 1;
    for i := 1 to 13 do
    begin
      if rankCount[i] > 0 then
      begin
       sequence := sequence + 1;
       if sequence = 5 then     { weaken this for testing! }
         begin
          isStraight := true;
          exit;
         end;
      end
      else
        sequence := 0;
    end;

{ check for Ace low and high? }
    if (rankCount[1] = 1) and (rankCount[2] = 1) and (rankCount[3] = 1) and
       (rankCount[4] = 1) and (rankCount[5] = 1) then
       isStraight := true
    else if (rankCount[1] = 1) and (rankCount[10] = 1) and (rankCount[11] = 1) and
       (rankCount[12] = 1) and (rankCount[13] = 1) then
      isStraight := true;
end;


{ evaluate the hand and print the result }
{ consider using an array to store scores, strings }
procedure evalHand(hand:tHand);
var
  i, j, suitMax, pairs : integer;
  t : string[20];
  rankCount : tRankCount; { array [1..13] of integer; }
  suitCount : array [1..4] of integer;

  straight, flush, straightFlush, royalFlush, fullHouse,
   onePair, twoPair, jacksOrBetter, threeOfAKind, fourOfAKind,
   ace, ten, jack, queen, king : boolean;

{ consider using an array of scores but it's a lot of work to set up }
{ and hardly seems worth it }
{ scores : array [1..11] of tScore; { nothing, pair, jacksorbetter .. RoyalFlush }

begin
{ set the counter arrays to zero }
  for i := 1 to 13 do rankCount[i] := 0;
  for i := 1 to 4  do suitCount[i] := 0;

{ set other flags and counters }
 t := 'Nothing!';
 score := -10;    { default score is to lose your bet?}
 suitMax := 0;
 pairs := 0;

 straight := false;
 flush := false;
 straightFlush := false;
 royalFlush := false;
 onePair := false;
 twoPair := false;
 jacksOrBetter := false;
 threeOfAKind := false;
 fullHouse := false;
 fourOfAKind := false;

 ace := false;
 ten := false;
 jack := false;
 queen := false;
 king := false;

{ tally the matches }
for i:= 1 to 5 do
   begin
     rankCount[ hand[i].rank ] :=  rankCount[ hand[i].rank ] + 1;
     suitCount[ hand[i].suit ] :=  suitCount[ hand[i].suit ] + 1;
   end;

{ now check for pairs, jacks or better, three, four of a kind }
for i := 1 to 13 do
begin
   if rankCount[i] = 2 then
     begin
      pairs := pairs + 1;
      if i in [1,11,12,13] then         { Ace, J, Q, K }
        jacksOrBetter := true;
      end;
   if rankCount[i] = 3 then
      threeOfAKind := true;
   if rankCount[i] = 4 then
      fourOfAKind := true;
end;

if (pairs = 1) then
begin
  onePair := true;
  if jacksOrBetter then
    begin
     t:= 'Jacks or better';
     score := 10;
    end
  else
  t := 'Only a pair';   { no score }
end;

if pairs = 2 then
begin
  twoPair := true;
  t := 'Two pair';
  score := 20;
end;

if threeOfAKind then
begin
 t := 'Three of a kind';
 score := 30;
end;

{ check for flush, e.g. suitMax = 5 }
{ note flush is better than 2 pairs, but less than full house }
for i:= 1 to 4 do
   if suitCount[i] > suitMax then
      suitMax := suitCount[i];
   if suitMax = 5 then         { weaken for testing }
    begin
      flush := true;
      t := 'Flush!';
      score := 50;
    end;

if threeofAKind and OnePair then
begin
  fullhouse := true;
  t := 'Full house!';
  score := 80;
end;

if fourOfAKind then t := 'Four of a kind!';

{ check for straight, straight flush etc. }

straight := isStraight(rankCount);
if straight then
begin
    t := 'Straight';
    score := 40;
end;

if straight and flush then
  begin
    t := 'Straight flush!';
    straightflush := true;
    score := 500;
    { check for royal flush }
    for i := 1 to 5 do
     case hand[i].rank of
      1: ace := true;
     10: ten := true;
     11: jack := true;
     12: queen := true;
     13: king := true;
    end;
   if ace and ten and jack and queen and king then   { weaken for testing }
       begin
         royalFlush := true;
         t := 'Royal flush!';
         score := 2500;
       end;
  end;
 gotoXY(2,11);
 write(t);
 clrEol;
 gotoXY(6,4);
end;


{ display the cards within the scoreboard box outlines }
procedure displayHand(hand:tHand);
var i,j : integer;
begin
  textColor(white);
  { blank out the card }
  for i := 1 to 5 do
  begin
    gotoxy((i*8)-4,6);
    for j := 1 to 4 do
    begin
      gotoxy((i*8)-4,5+j);
      write('     ');
    end;
  { now print the rank and suit }

   if (hand[i].suit = 2) or (hand[i].suit = 3) then { diamond or heart }
     textColor(Lightred)
   else
     textColor(LightCyan);

   gotoxy((i*8)-4,6);
   write(hand[i].r);
   gotoXY((i*8)-2,7);
   write(hand[i].s);
   if hand[i].rank = 10 then    { leave more space }
     gotoXY((i*8)-1,9)
   else
     gotoXY(i*8,9);
   write(hand[i].r);
  end;
end;

{ anintroductory screen at the start and end of the game }
procedure introScreen;
var i : integer;
begin
 clrScr;
 gotoXY(0,0);
 textColor(green);
 writeln(' Tahoe 5                     Video Poker');
 writeln(' V2.0                         08/19/2025');
 writeln('                        Turbo Pascal 4.0');
 writeln;
 textColor(white);
 writeln('                 ÚÄÄÚÄÄÚÄÄÚÄÄÚÄÄÄÄÄ¿');
 writeln('                 ³10³J ³Q ³K ³A    ³');
 writeln('                 ³  ³  ³  ³  ³     ³');
 writeln('                 ³  ³  ³  ³  ³    A³');
 writeln('                 ÀÄÄÀÄÄÀÄÄÀÄÄÀÄÄÄÄÄÙ');
 textcolor(LightRed);
 for i:= 0 to 4 do         { write the heart symbol }
  begin
   gotoXY((3*i)+19,7);
   write(chr(3));
  end;
  gotoXY(34,8);
  write(chr(5));
  gotoXY(1,12);
  textcolor(green);
  writeln(' [S] = Sound Off');
  writeln(' [Enter] = Play [Esc] = Quit  [H] = Help');
  writeln(' Copyright  1992 - 2025 M. Zack Urlocker');
  gotoXY(3,12);
end;

procedure HelpScreen;
var key : char;
begin
 clrScr;
 textColor(yellow);
 writeln;
 writeln(' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿');
 writeln(' ³ Tahoe 5 plays video poker. Press the ',chr(24), chr(25),' arrows  ³');
 writeln(' ³ to change the bet. Press [1-5] to hold. [S] for ³');
 writeln(' ³ Sound. [Enter] draws new cards. [Esc] to quit.  ³');
 writeln(' ³                                                 ³');
 writeln(' ³ I wrote the original version in 1992 with Turbo ³');
 writeln(' ³ Pascal 6.0 with objects. DOS, Windows and Atari ³');
 writeln(' ³ Portfolio versions were released as shareware   ³');
 writeln(' ³ along with a video BlackJack game.              ³');
 writeln(' ³                                                 ³');
 writeln(' ³ I lost the source code decades ago and decided  ³');
 writeln(' ³ to rewrite it in Turbo Pascal 4.0 using DosBox  ³');
 writeln(' ³ on a Mac (with ChatGPT assistance) to rebuild   ³');
 writeln(' ³ my rusty programming chops.                     ³');
 writeln(' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ Thank you! ÄÙ');
 key := readKey;
end;

{ display the adjusted bet in the scoreboard screen }
procedure displayBet;
begin
 gotoXY(2,1);
 write('Bet: $', bet,' ');
end;

{ display the adjusted balance in the scoreboard screen }
procedure displayBalance;
begin
 gotoxy(12,2);
 write(balance,' ');
end;

{ draw the basic score board with blank cards }
procedure scoreBoard;
begin
 clrScr;
 textColor(green);
 writeln(' Bet: $         [Enter] = Deal [Esc] = Quit');
 writeln(' Balance: $                      [H] = Help');
 writeln;
 textcolor(white);
 writeln('     1       2       3       4       5   ');
 writeln('  ÚÄÄÄÄÄ¿ ÚÄÄÄÄÄ¿ ÚÄÄÄÄÄ¿ ÚÄÄÄÄÄ¿ ÚÄÄÄÄÄ¿');
 writeln('  ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³');
 writeln('  ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³');
 writeln('  ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³');
 writeln('  ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³ ³°°°°°³');
 writeln('  ÀÄÄÄÄÄÙ ÀÄÄÄÄÄÙ ÀÄÄÄÄÄÙ ÀÄÄÄÄÄÙ ÀÄÄÄÄÄÙ');
 writeln;
 writeln;
 writeln;
 writeln;
 textColor(LightBlue);
 writeln(' Payoffs:              Flush           50');
 writeln('  Royal Flush   2500   Straight        40');
 writeln('  Straight Flush 500   Three of a kind 30');
 writeln('  Four of a kind 250   Two pair        20');
 writeln('  Full house      80   Jacks or better 10');
 textColor(green);
 displayBet;
 displayBalance;
 gotoXY(12,1);
 write(char(24),char(25));  { up and down arrows }
end;


{ increase the bet, but check the balance }
procedure increaseBet;
begin
  if balance > 0 then
    begin
     bet := bet + 10;
     balance := balance - 10;
     displayBet;
     displayBalance;
    end
  else
    loBeep;
  gotoXY(11,1);  { place cursor near bet amount }
end;

{ decrease the bet, but $10 minimum }
procedure decreaseBet;
begin
  if bet > 10 then
   begin
    bet := bet - 10;
    balance := balance + 10;
    displayBet;
    displayBalance;
   end
   else
     loBeep;
  gotoXY(11,1);   { place cursor near bet amount }
end;


{ Main program }
Begin
   soundOn := True;
   score := 0;
   balance := 90;

   introScreen;
   key := upCase(readKey);

   if key = 'S' then
      SoundOn := not(soundOn)
   else
   if key = 'H' then
      helpScreen
   else
      if key = #27 then { Escape }
        halt
      else
      if key = #0 then  { extended key [F1] }
        begin           { doesn't seem to work }
          key := readKey;
          if key = #79 then
            helpScreen;
        end;

   startingSound;
   repeat { new hand }
    bet := 10;
    ClrScr;
    scoreBoard;

    initDeck(deck);
    shuffle(deck);
    top := 1;       { next card to deal in deck  }
    gotoXY(11,1);   { put cursor near bet amount }

    { user can use arrows to increase, decrease bet }
    { wait for [Enter] to deal }
    repeat
     key := upCase(readKey);
     if key =#0 then       { extended key for arrows }
       begin
         hiBeep;
         key := readKey;
         if (key = #72) or (key = #77) then   { up or right }
           increaseBet;
         if (key = #80) or (key = #75) then   { down or left }
             decreaseBet;
       end
    else
    if key = 'S' then
       SoundOn := not(soundOn)
     else if key = 'H' then
       begin
        helpScreen;
        scoreBoard;
       end
     else if key = #27 then    { [Esc] }
       begin
        introScreen;
        halt;
       end;
    until key = #13;           { [Enter] }

   { deal 5 cards }
   for i:= 1 to 5 do
   begin
      hand[i] := deck[i];
      hold[i] := false;
      top := top + 1;
   end;
   displayhand(hand);
   gotoXY(12,1);
   write('  ');  { erase arrows }
   gotoXY(18,2);
   textColor(green);
   write('[1-5] = Hold');
   gotoXY(6,4); { put cursor near card number 1 }

   repeat       { hold or get new cards }

    { Hold array identifies which cards are held, e.g. not replaced }
     key := upCase(readKey);
     if key = 'H' then      { bug: in this case the hold text is lost }
     begin
       helpScreen;
       scoreboard;          { wipes out the hold status text, oh well! }
       displayHand(hand);   { need to redraw Hold status!}
       gotoXY(6,4);
     end
     else
       if key = 'S' then
         soundOn := not(soundOn)
     else
     begin
     textColor(white);
     i := ord(key) - ord('0');
     if (i >= 1) and (i <= 5) then
      begin
        loBeep;
        hold[i] := not(hold[i]);  { toggle }
        gotoxy((i*8)-3,4);
        if hold[i] then
          write('Hold')
        else
          begin
           str(i, indexStr);
           write(' ', indexStr, '  ');
          end;
        gotoXY((i*8)-2,4);
      end;
     end;
     until key in ['Q', #13, #27] ;    { Q, [Enter] or [Esc] }

  { get the new cards }
     for i:= 1 to 5 do
     if not(hold[i]) then
         begin
          hand[i] := deck[top];   { draw card }
          top := top + 1;         { next card }
         end;

  displayHand(hand);
  textColor(yellow);
  evalhand(hand);     { and print the result }


  { adjust the score based on bet size }
  if score >= 80 then   { full house or better }
     GreatWinningSound
  else
     if score >=40 then { straight or better }
       winningSound;
  score := round(bet/10) * score;
  if score > 0 then
     balance := balance + score;
  gotoXY(2,12);
  if score > 0 then
    writeln('You win: ',score)
  else
    writeln('You lose: ', bet);
  textColor(green);
  displayBalance;

  balance := balance - 10;   { new balance for next hand }
  { bail out the player if balance is zero }
  if balance <= 0 then
    begin
      balance := 90;  { initial bet is $10 }
      gotoXY(2,12);
      writeLn('Emergency loan $100!');
      losingSound;
      case random(6) of
        0: writeln(' You must be new to this game!');
        1: writeln(' Maybe you are lucky in other ways!');
        2: writeln(' Have you thought about other hobbies?');
        3: writeln(' Therapy might be cheaper!');
        4: writeln(' Better luck next time.');
        5: writeln(' Deposit car keys now.');
       end;
    end;
  if (key = #13) then  { [Enter] }
    begin
     textColor(yellow);
     gotoxy(26,11);
     write('New hand? [Enter] ');
     gotoXY(31,12);
     write('Quit = [Esc]');
     gotoXY(43,11);
     key := upCase(readKey);
    end;

  until (key = 'Q') or (key = 'N') or (key = #27);   { [Esc] }
  introScreen;
  gotoXY(3,15);
  writeln;
End.