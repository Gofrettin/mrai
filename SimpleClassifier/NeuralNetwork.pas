// ###################################################################
// #### This file is part of the artificial intelligence project, and is
// #### offered under the licence agreement described on
// #### http://www.mrsoft.org/
// ####
// #### Copyright:(c) 2016, Michael R. . All rights reserved.
// ####
// #### Unless required by applicable law or agreed to in writing, software
// #### distributed under the License is distributed on an "AS IS" BASIS,
// #### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// #### See the License for the specific language governing permissions and
// #### limitations under the License.
// ###################################################################

unit NeuralNetwork;

// ###########################################
// #### Artificial Feed Forward Neural Networks
// #### -> first version includes a very base
// #### backpropagation learning algorithm following the
// #### proposed algorithm from the neural network lecture of H. Bishof
// ###########################################

// -> the input neurons are normed suched that the maximum input
//    values are around the input examples mean and scaled.

interface

uses Types, BaseClassifier, BaseMathPersistence;

// base simple neuron
type
  TNeuronType = (ntLinear, ntExpSigmoid, ntTanSigmoid, ntExpSigFast);
type
  TNeuron = class(TBaseMathPersistence)
  private
    fBeta : double;
    fNeuralType : TNeuronType;
    fWeights : TDoubleDynArray;

    // additional data only used in the learning step:
    fDeltaWM1 : TDoubleDynArray; // wheights update in the learning step before

    // helper functions for learning
    function Derrive(const outputVal : double) : double;
    procedure RandomInit(const RangeMin : double = -1; const RangeMax : double = 1);
  public
    function Feed(const Input : TDoubleDynArray) : double;

    procedure DefineProps; override;
    function PropTypeOfName(const Name : string) : TPropType; override;

    procedure OnLoadDoubleProperty(const Name : String; const Value : double); override;
    procedure OnLoadIntProperty(const Name : String; Value : integer); override;
    procedure OnLoadDoubleArr(const Name : String; const Value : TDoubleDynArray); override;

    constructor Create(NumInputs : integer; nnType : TNeuronType);
  end;

// one layer -> collection of neurons
type
  TNeuralLayer = class(TBaseMathPersistence)
  private
    fNeurons : Array of TNeuron;
    fType : TNeuronType;

    fLoadIdx : integer;
  public
    function Feed(const Input : TDoubleDynArray) : TDoubleDynArray;

    procedure DefineProps; override;
    function PropTypeOfName(const Name : string) : TPropType; override;
    procedure OnLoadBeginList(const Name : String; count : integer); override;
    function OnLoadObject(Obj : TBaseMathPersistence) : boolean; override;
    procedure OnLoadEndList; override;

    procedure OnLoadIntProperty(const Name : String; Value : integer); override;

    constructor Create(NumInputs, NumNeurons : integer; NeuronType : TNeuronType);
    destructor Destroy; override;
  end;

// a complete feed forward net
type
  TNeuralLayerRec = record
    NumNeurons : integer;
    NeuronType : TNeuronType;
  end;
  TNeuralLayerRecArr = Array of TNeuralLayerRec;
  TNeuralMinMax = packed Array[0..1] of double; //0..min, 1..max
  TNeuralMinMaxArr = Array of TNeuralMinMax;
  TFeedForwardNeuralNet = class(TBaseMathPersistence)
  private
    fLayer : Array of TNeuralLayer;
    fInputMinMax : TNeuralMinMaxArr;
    fInputMeanVar : TNeuralMinMaxArr;
    fOutputMinMax : TNeuralMinMax;

    fLoadIdx : integer;
  public
    function Feed(const Input : TDoubleDynArray) : TDoubleDynArray;

    procedure DefineProps; override;
    function PropTypeOfName(const Name : string) : TPropType; override;

    procedure OnLoadBeginList(const Name : String; count : integer); override;
    function OnLoadObject(Obj : TBaseMathPersistence) : boolean; override;
    procedure OnLoadEndList; override;
    procedure OnLoadBinaryProperty(const Name : String; const Value; size : integer); override;

    constructor Create(NumInputs : integer; const layers : TNeuralLayerRecArr; const InputMinMax, InputMeanVar : TNeuralMinMaxArr);
    destructor Destroy; override;
  end;


type
  TNeuralNetLearnAlg = (nnBackprop, nnBackpropMomentum);
  TNeuralNetProps = record
    learnAlgorithm : TNeuralNetLearnAlg;
    layers : TNeuralLayerRecArr; // without the output layer!
    outputLayer : TNeuronType;   // output neuron type. (number of output neurons is the number of classes
    eta : double;                // learning rate
    alpha : double;              // used in the momentum algorithm as multiplier of the second term learning rate
    cf : double;                 // flat spot elimination constant (used in momentum backprop)
    l1Normalization : double;    // normalization factor used in the weight update proc
    maxNumIter : integer;        // maximum number of batch iterations
    minNumIter : integer;        // minimum number of batch iterations (despite the error change)
    stopOnMinDeltaErr : double;  // when training error change is lower than this delta then stop training
    validationDataSetSize : double; // percentage (0-1) to be used as validation data set. if set to 0 the training
                                    // set is used for validation.
    numMinDeltaErr : integer;    // number of batch iterations that needs to be lower than stopOnMinDeltaErr
    normMeanVar : boolean;       // the input is normaized to (x - mean_i)/var_i  where mean_i is the mean of that feature and var_i is it's variance
  end;

// ###########################################
// #### Feed forward neural net classifier
type
  TNeuralNet = class(TCustomClassifier)
  private
    fNet : TFeedForwardNeuralNet;
    fClasses : TIntegerDynArray;
  public
    function Classify(Example : TCustomExample; var confidence : double) : integer; overload; override;

    function OnLoadObject(const Name : String; Obj : TBaseMathPersistence) : boolean; overload; override;
    procedure OnLoadIntArr(const Name : String; const Value : TIntegerDynArray); override;

    procedure DefineProps; override;
    function PropTypeOfName(const Name : string) : TPropType; override;

    constructor Create(aNet : TFeedForwardNeuralNet; aClassList : TIntegerDynArray);
    destructor Destroy; override;
  end;

// ###########################################
// #### Simple feed forward neural net learning class
type
  TNeuralNetLearner = class(TCustomWeightedLearner)
  private
    fProps : TNeuralNetProps;

    fOk : Array of TDoubleDynArray;
    fnumFeatures : integer;
    fdeltaK, fdeltaI : TDoubleDynArray;
    fnumCl : integer;
    fclassLabels : TIntegerDynArray;
    foutputExpAct : TDoubleDynArray;
    fMaxNumNeurons : integer;
    fCurExampleWeight : double;
    fWeights : TDoubleDynArray;

    function DataSetMinMax : TNeuralMinMaxArr;
    function DataSetMeanVar : TNeuralMinMaxArr;
    procedure UpdateWeights(deltaK : double; outputs : TDoubleDynArray; neuron : TNeuron);
    procedure UpdateWeightsByLearnRate(deltaK : double; outputs : TDoubleDynArray; neuron : TNeuron);
    procedure UpdateWeightsMomentum(deltaK : double; outputs : TDoubleDynArray; neuron : TNeuron);
    procedure BackProp(net : TFeedForwardNeuralNet; randSet: TCustomLearnerExampleList; idx : TIntegerDynArray);
  protected
    function DoLearn(const weights : Array of double) : TCustomClassifier; override;
  public
    procedure SetProps(const Props : TNeuralNetProps);

    class function CanLearnClassifier(Classifier : TCustomClassifierClass) : boolean; override;
  end;

implementation

uses Math, SysUtils, BaseMatrixExamples, Matrix, MatrixASMStubSwitch, 
     MatrixConst;

// ################################################
// ##### persistence
// ################################################

const cClassLabels = 'labels';
      cNeuralNet = 'feedforwardnet';
      cNetLayers = 'layers';
      cInputMinMax = 'inputMinMax';
      cOutputMinMax = 'outputMinMax';
      cInputMeanVar = 'inputMeanVar';

      cNeuronType = 'neuronType';
      cNeuronList = 'neurons';

      cNeuronThresh = 'neuronThresh';
      cNeuronWeights = 'neuronWeights';
      cNeuronBeta = 'neuronBeta';
{ TNeuron }

constructor TNeuron.Create(NumInputs: integer; nnType: TNeuronType);
begin
     inherited Create;

     fNeuralType := nnType;

     fBeta := 1;
     SetLength(fWeights, NumInputs + 1);
end;

function TNeuron.Feed(const Input : TDoubleDynArray): double;
var absRes : double;
    invBeta : double;
    sign : double;
const cD1 : double = (0.8808 - 0.5)/2;   // slope between -2:2
      cD2 : double = (1 - 0.8808)/3;     // slope between 2:5
begin
     assert(Length(input) + 1 = length(fWeights), 'Error input does not match learned weights');

     Result := fWeights[0] + MatrixVecDotMult( @Input[0], sizeof(double), @fWeights[1], sizeof(double), Length(Input) );
     //for i := 0 to Length(Input) - 1 do
//         Result := Result + Input[i]*fWeights[i + 1];

     case fNeuralType of
       //ntPerceptron: Result := ifthen(Result < fThresh, 0, 1);
       ntLinear: Result := Result;
       ntExpSigmoid: Result := 1/(1 + exp(-fBeta*(Result)));
       ntTanSigmoid: Result := tanh(fBeta*(Result));
       ntExpSigFast: begin
                          absRes := abs(Result);
                          invBeta := 1/fBeta;     
                          sign := 1;
                          if Result < 0 then
                             sign := -1;
                          
                          if absRes <= 2*invBeta 
                          then
                              Result := 0.5 + fBeta*cD1*Result
                          else if sign < 0 
                          then
                              Result := (1 - 0.8808) + sign*(absRes - 2)*cD2*fBeta
                          else
                              Result := 0.8808 + sign*(absRes - 2)*cD2*fBeta;

                          Result := Max(0, Min(1, Result));
                     end;
     end;
end;

procedure TNeuron.RandomInit(const RangeMin : double = -1; const RangeMax: double = 1);
var i : Integer;
begin
     for i := 0 to Length(fWeights) - 1 do
         fWeights[i] := Random*(rangeMax - rangeMin) + RangeMin;
end;

function TNeuron.Derrive(const outputVal: double): double;
begin
     case fNeuralType of
       ntLinear: Result := fBeta;
       ntExpSigmoid,
       ntExpSigFast: Result := fBeta*(outputVal*(1 - outputVal));
       ntTanSigmoid: Result := fBeta*(1 - sqr(outputVal));
     else
         Result := 0;
     end;
end;

procedure TNeuron.DefineProps;
begin
     inherited;

     AddDoubleProperty(cNeuronBeta, fBeta);
     AddIntProperty(cNeuronType, Integer(fNeuralType));
     AddDoubleArr(cNeuronWeights, fWeights);
end;

function TNeuron.PropTypeOfName(const Name: string): TPropType;
begin
     if (CompareText(Name, cNeuronBeta) = 0) or (CompareText(Name, cNeuronWeights) = 0)
     then
         Result := ptDouble
     else if CompareText(Name, cNeuronType) = 0
     then
         Result := ptInteger
     else
         Result := inherited PropTypeOfName(Name);
end;

procedure TNeuron.OnLoadIntProperty(const Name: String; Value: integer);
begin
     if SameText(Name, cNeuronType)
     then
         fNeuralType := TNeuronType(Value)
     else
         inherited;
end;

procedure TNeuron.OnLoadDoubleProperty(const Name: String; const Value: double);
begin
     if SameText(Name, cNeuronBeta)
     then
         fBeta := Value
     else
         inherited;
end;

procedure TNeuron.OnLoadDoubleArr(const Name: String;
  const Value: TDoubleDynArray);
begin
     if SameText(Name, cNeuronWeights)
     then
         fWeights := Value
     else
         inherited;
end;

{ TNeuralLayer }

constructor TNeuralLayer.Create(NumInputs, NumNeurons: integer;
  NeuronType: TNeuronType);
var i : integer;
    mult : double;
begin
     inherited Create;

     fType := NeuronType;
     SetLength(fNeurons, NumNeurons);

     mult := 1/sqrt(NumInputs);

     for i := 0 to Length(fNeurons) - 1 do
     begin
          fNeurons[i] := TNeuron.Create(NumInputs, NeuronType);
          fNeurons[i].RandomInit(-1*mult, 1*mult);
     end;
end;

function TNeuralLayer.Feed(const Input: TDoubleDynArray): TDoubleDynArray;
var i : integer;
begin
     SetLength(Result, Length(fNeurons));

     for i := 0 to Length(fNeurons) - 1 do
         Result[i] := fNeurons[i].Feed(Input);
end;

destructor TNeuralLayer.Destroy;
var counter: Integer;
begin
     for counter := 0 to Length(fNeurons) - 1 do
         fNeurons[counter].Free;

     inherited;
end;

procedure TNeuralLayer.DefineProps;
var counter : integer;
begin
     inherited;

     AddIntProperty(cNeuronType, Integer(fType));
     BeginList(cNeuronList, Length(fNeurons));
     for counter := 0 to Length(fNeurons) - 1 do
         AddObject(fNeurons[counter]);
     EndList;
end;

function TNeuralLayer.PropTypeOfName(const Name: string): TPropType;
begin
     if CompareText(Name, cNeuronType) = 0
     then
         Result := ptInteger
     else if CompareText(Name, cNeuronList) = 0
     then
         Result := ptObject
     else
         Result := inherited PropTypeOfName(Name);
end;

procedure TNeuralLayer.OnLoadIntProperty(const Name: String; Value: integer);
begin
     if SameText(Name, cNeuronType)
     then
         fType := TNeuronType(Value)
     else
         inherited;
end;

procedure TNeuralLayer.OnLoadBeginList(const Name: String; count: integer);
begin
     fLoadIdx := -1;
     if SameText(Name, cNeuronList) then
     begin
          SetLength(fNeurons, count);
          fLoadIdx := 0;
     end
     else
         inherited;
end;

function TNeuralLayer.OnLoadObject(Obj: TBaseMathPersistence): boolean;
begin
     Result := True;
     if fLoadIdx >= 0 then
     begin
          fNeurons[fLoadIdx] := obj as TNeuron;
          inc(fLoadIdx);
     end
     else
         Result := inherited OnLoadObject(obj);
end;

procedure TNeuralLayer.OnLoadEndList;
begin
     if fLoadIdx >= 0
     then
         fLoadIdx := -1
     else
         inherited;
end;

{ TFeedForwardNeuralNet }

constructor TFeedForwardNeuralNet.Create(NumInputs: integer;
  const layers: TNeuralLayerRecArr; const InputMinMax, InputMeanVar : TNeuralMinMaxArr);
var i : integer;
    lastNumInputs : integer;
    minVal, maxVal : double;
procedure SetBetaAndThreshFirstLayer(aBeta : double; layer : TNeuralLayer);
var counter : integer;
begin
     for counter := 0 to Length(layer.fNeurons) - 1 do
     begin
          layer.fNeurons[counter].fWeights[0] := 0; //InputMinMax[counter][0] + InputMinMax[counter][1])/2;
          layer.fNeurons[counter].fBeta := aBeta;
     end;
end;

procedure SetBetaAndThresh(aBeta, aThresh : double; layer : TNeuralLayer);
var counter : integer;
begin
     for counter := 0 to Length(layer.fNeurons) - 1 do
     begin
          layer.fNeurons[counter].fWeights[0]:= -aThresh;
          layer.fNeurons[counter].fBeta := aBeta;
     end;
end;
begin
     SetLength(fLayer, Length(layers));

     fInputMinMax := InputMinMax;
     fInputMeanVar := InputMeanVar;

     fOutputMinMax[1] := 1;
     case layers[High(layers)].NeuronType of
       ntLinear,
       ntTanSigmoid : fOutputMinMax[0] := -1;
       ntExpSigmoid,
       ntExpSigFast : fOutputMinMax[0] := 0;
     end;

     lastNumInputs := NumInputs;
     for i := 0 to Length(fLayer) - 1 do
     begin
          fLayer[i] := TNeuralLayer.Create(lastNumInputs, layers[i].NumNeurons, layers[i].NeuronType);
          lastNumInputs := layers[i].NumNeurons;
     end;

     minVal := MaxDouble;
     maxVal := -MaxDouble;
     for i := 0 to Length(fInputMinMax) - 1 do
     begin
          minVal := Min(minVal, fInputMinMax[i][0]);
          maxVal := Max(maxVal, fInputMinMax[i][1])
     end;

     // adjust the input activation by the min max values and according to the input neuron type
     case fLayer[0].fType of
       ntLinear:  SetBetaAndThreshFirstLayer( 1, fLayer[0]);
       ntExpSigmoid,
       ntExpSigFast: SetBetaAndThreshFirstLayer(10/(maxVal - minVal), fLayer[0]);
       ntTanSigmoid: SetBetaAndThreshFirstLayer(2*pi/(maxVal - minVal), fLayer[0]);
     end;

     for i := 1 to Length(fLayer) - 1 do
     begin
          if not (fLayer[i - 1].fType in [ntExpSigmoid, ntExpSigFast])
          then
              SetBetaAndThresh(1, 0, fLayer[i])
          else
              SetBetaAndThresh(1, 0.5, fLayer[i]);
     end;
end;

destructor TFeedForwardNeuralNet.Destroy;
var i : integer;
begin
     for i := 0 to Length(fLayer) - 1 do
         fLayer[i].Free;

     inherited;
end;

function TFeedForwardNeuralNet.Feed(const Input: TDoubleDynArray): TDoubleDynArray;
var i : integer;
begin
     SetLength(Result, Length(input));
     Result := Input;

     // normalize by mean and var
     for i := 0 to Length(input) - 1 do
         Result[i] := (Result[i] - fInputMeanVar[i][0])/fInputMeanVar[i][1];

     for i := 0 to Length(fLayer) - 1 do
         Result := fLayer[i].Feed(Result);
end;

procedure TFeedForwardNeuralNet.DefineProps;
var counter: Integer;
begin
     inherited;

     BeginList(cNetLayers, Length(fLayer));
     for counter := 0 to Length(fLayer) - 1 do
         AddObject(fLayer[counter]);
     EndList;

     AddBinaryProperty(cInputMinMax, fInputMinMax, sizeof(TNeuralMinMax)*Length(fInputMinMax));
     AddBinaryProperty(cOutputMinMax, fOutputMinMax, sizeof(fOutputMinMax));
     AddBinaryProperty(cInputMeanVar, fInputMeanVar, sizeof(TNeuralMinMax)*Length(fInputMeanVar));
end;

function TFeedForwardNeuralNet.PropTypeOfName(const Name: string): TPropType;
begin
     if CompareText(Name, cNetLayers) = 0
     then
         Result := ptObject
     else if (CompareText(Name, cInputMinMax) = 0) or (CompareText(Name, cOutputMinMax) = 0) or (CompareText(Name, cInputMeanVar) = 0)
     then
         Result := ptBinary
     else
         Result := inherited PropTypeOfName(Name);
end;


procedure TFeedForwardNeuralNet.OnLoadBinaryProperty(const Name: String;
  const Value; size: integer);
begin
     if SameText(Name, cInputMinMax) then
     begin
          assert(Size mod sizeof(TNeuralMinMax) = 0, 'Error persistent size of Input Min Max differs');
          SetLength(fInputMinMax, Size div sizeof(TNeuralMinMax));
          Move(Value, fInputMinMax[0], Size);
     end
     else if SameText(Name, cOutputMinMax) then
     begin
          assert(Size = sizeof(fInputMinMax), 'Error persistent size of Input Min Max differs');
          Move(Value, fOutputMinMax, Size);
     end
     else if SameText(Name, cInputMeanVar) then
     begin
          assert(Size mod sizeof(TNeuralMinMax) = 0, 'Error persistent size of Input Min Max differs');
          SetLength(fInputMeanVar, Size div sizeof(TNeuralMinMax));
          Move(Value, fInputMeanVar[0], Size);
     end;
         inherited;
end;

procedure TFeedForwardNeuralNet.OnLoadBeginList(const Name: String;
  count: integer);
begin
     fLoadIdx := -1;
     if SameText(Name, cNetLayers) then
     begin
          SetLength(fLayer, count);
          fLoadIdx := 0;
     end
     else
         inherited;
end;

procedure TFeedForwardNeuralNet.OnLoadEndList;
begin
     if fLoadIdx <> -1
     then
         fLoadIdx := -1
     else
         inherited;
end;

function TFeedForwardNeuralNet.OnLoadObject(Obj: TBaseMathPersistence): boolean;
begin
     Result := True;
     if fLoadIdx >= 0 then
     begin
          fLayer[fLoadIdx] := obj as TNeuralLayer;
          inc(fLoadIdx);
     end
     else
         Result := inherited OnLoadObject(Obj);
end;

{ TNeuralNetLearner }

procedure TNeuralNetLearner.BackProp(net : TFeedForwardNeuralNet; randSet : TCustomLearnerExampleList;
  idx : TIntegerDynArray);
var exmplCnt : integer;
    counter : integer;
    actIdx : integer;
    layerCnt : integer;
    lastClass : integer;
    neuronCnt : integer;
    tmp : TDoubleDynArray;
begin
     // init section
     if fOk = nil then
     begin
          SetLength(fOk, 2 + Length(fProps.layers));
          SetLength(fOk[0], fnumFeatures);
          SetLength(foutputExpAct, fnumCl);

          SetLength(fdeltak, fMaxNumNeurons);
          SetLength(fdeltaI, fMaxNumNeurons);
     end;

     if fProps.learnAlgorithm <> nnBackpropMomentum then
        fProps.cf := 0;

     lastClass := MaxInt;

     // ###############################################
     // #### Performs one batch backpropagations step on the given randomized data set
     // it reuses some global object variables
     for exmplCnt := 0 to randSet.Count - 1 do
     begin
          fCurExampleWeight := fWeights[idx[exmplCnt]];
          
          // define wanted output activation for the current example
          if randSet.Example[idx[exmplCnt]].ClassVal <> lastClass then
          begin
               actIdx := -1;
               for counter := 0 to fNumCl - 1 do
               begin
                    if fClassLabels[counter] = randSet.Example[idx[exmplCnt]].ClassVal then
                    begin
                         actIdx := counter;
                         break;
                    end;
               end;

               for counter := 0 to fnumCl - 1 do
                   foutputExpAct[counter] := net.fOutputMinMax[IfThen(counter = actIdx, 1, 0) ];
          end;

          for counter := 0 to fNumFeatures - 1 do
              fOk[0][counter] := randSet[idx[exmplCnt]].FeatureVec[counter];

          // first layer -> normalize input by mean var of the complete input
          for counter := 0 to fnumFeatures - 1 do
              fOk[0][counter] := (fOk[0][counter] - net.fInputMeanVar[counter][0])/net.fInputMeanVar[counter][1];

          // calculate activation (o_k) for all layers
          for layerCnt := 0 to Length(net.fLayer) - 1 do
              fOk[layerCnt + 1] := net.fLayer[layerCnt].Feed(fOk[layerCnt]);

          // output layer -> activation error is calculatead against the expected output
          for neuronCnt := 0 to Length(fok[length(fok) - 1]) - 1 do
          begin
               fdeltak[neuronCnt] := (foutputExpAct[neuronCnt] - fok[Length(fok) - 1][neuronCnt])*
                                     (fProps.cf +
                                      net.fLayer[Length(net.fLayer) - 1].fNeurons[neuronCnt].Derrive(fok[Length(fok) - 1][neuronCnt])
                                     );
               // update weights of the final neuron
               UpdateWeights(fdeltaK[neuronCnt], fok[Length(fok) - 2], net.fLayer[Length(net.fLayer) - 1].fNeurons[neuronCnt]);
          end;

          // propagate error through the layers and update weights
          for layerCnt := Length(fProps.layers) - 1 downto 0 do
          begin
               // switch deltai and deltak (faster reallocation ;) )
               tmp := fdeltaK;
               fdeltaK := fdeltaI;
               fdeltaI := tmp;

               // #############################################
               // #### backpropagation step
               for neuronCnt := 0 to fProps.layers[layerCnt].NumNeurons - 1 do
               begin
                    fdeltaK[neuronCnt] := 0;

                    for counter := 0 to Length(net.fLayer[layerCnt + 1].fNeurons) - 1 do
                        fdeltaK[neuronCnt] := fdeltaK[neuronCnt] +
                                              fdeltaI[counter]*
                                              (fProps.cf +
                                               net.fLayer[layerCnt + 1].fNeurons[counter].fWeights[neuronCnt]);
                    fdeltaK[neuronCnt] := fdeltaK[neuronCnt]*net.fLayer[layerCnt].fNeurons[neuronCnt].Derrive(fOk[layerCnt + 1][neuronCnt]);

                    // update weights of the current neuron
                    UpdateWeights(fdeltaK[neuronCnt], fOk[layerCnt], net.fLayer[layercnt].fNeurons[neuronCnt]);
               end;
          end;
     end;
end;

function TNeuralNetLearner.DoLearn(const weights : Array of double) : TCustomClassifier; 
var net : TFeedForwardNeuralNet;
    layers : TNeuralLayerRecArr;
    counter: Integer;
    learnCnt : integer;
    lastErr, curErr : double;
    numSmallErrChange : integer;
    errCnt : integer;
    inputMinMax, inputMeanVar : TNeuralMinMaxArr;
    randSet : TCustomLearnerExampleList;
    validationSet : TCustomLearnerExampleList;
    maxVal : double;
    shuffIdx : TIntegerDynArray;
begin
     SetLength(fWeights, Length(weights));

     // idea to use weights: multiply the weight update by the example weight.
     // normalize weights to 1
     maxVal := MaxValue(weights);
     for counter := 0 to Length(weights) - 1 do
         fWeights[counter] := weights[counter]/maxVal;
     
     fclassLabels := Classes;
     fnumCl := Length(fclassLabels);
     fnumFeatures := DataSet.Example[0].FeatureVec.FeatureVecLen;

     fMaxNumNeurons := Max(fNumCl, fnumFeatures);

     for counter := 0 to Length(fProps.layers) - 1 do
         fMaxNumNeurons := Max(fMaxNumNeurons, fProps.layers[counter].NumNeurons);

     SetLength(layers, Length(fProps.layers) + 1);
     layers[Length(layers) - 1].NeuronType := fProps.outputLayer;
     layers[Length(layers) - 1].NumNeurons := fnumCl;

     inputMinMax := DataSetMinMax;
     inputMeanVar := DataSetMeanVar;

     if not fProps.normMeanVar then
     begin
          for counter := 0 to Length(inputMeanVar) - 1 do
          begin
               inputMeanVar[counter][0] := 0;
               inputMeanVar[counter][1] := 1;
          end;
     end;

     if Length(fProps.layers) > 0 then
        Move(fProps.layers[0], layers[0], Length(fProps.layers)*sizeof(fProps.layers[0]));

     net := TFeedForwardNeuralNet.Create(fnumFeatures, layers, inputMinMax, inputMeanVar);

     lastErr := 1;
     numSmallErrChange := 0;

     // ###########################################
     // #### create classifier
     Result := TNeuralNet.Create(net, Classes);

     // ###########################################
     // #### create Traingin sets
     Dataset.CreateTrainAndValidationSet(Round(100*fProps.validationDataSetSize), randSet, validationSet);

     // #########################################################
     // ##### batch error evaluation
     for learnCnt := 0 to fProps.maxNumIter - 1 do
     begin
          DoProgress(100*learnCnt div fProps.maxNumIter);
          // ##########################################################
          // #### One batch learn iteration (randomized data set)
          shuffIdx := randSet.Shuffle;
          Backprop(net, randSet, shuffIdx);

          // ##################################################
          // #### test learning error
          curErr := 0;
          for errCnt := 0 to validationSet.Count - 1 do
          begin
               if Result.Classify(validationSet.Example[errCnt]) <> validationSet.Example[errCnt].ClassVal then
                  curErr := curErr + 1;
          end;
          curErr := curErr/validationSet.Count;

          if (learnCnt >= fProps.minNumIter) and (lastErr - curErr < fProps.stopOnMinDeltaErr) then
          begin
               inc(numSmallErrChange);

               if numSmallErrChange >= fProps.numMinDeltaErr then
                  break;
          end
          else
          begin
               lastErr := curErr;
               numSmallErrChange := 0;
          end;
     end;

     randSet.Free;
     validationSet.Free;
end;

procedure TNeuralNetLearner.UpdateWeights(deltaK: double;
  outputs: TDoubleDynArray; neuron: TNeuron);
begin
     case fProps.learnAlgorithm of
       nnBackprop: UpdateWeightsByLearnRate(deltaK, outputs, neuron);
       nnBackpropMomentum: UpdateWeightsMomentum(deltaK, outputs, neuron);
     end;
end;

procedure TNeuralNetLearner.SetProps(const Props: TNeuralNetProps);
begin
     fProps := Props;
end;

function TNeuralNetLearner.DataSetMinMax: TNeuralMinMaxArr;
var counter : integer;
    featureCnt : integer;
begin
     SetLength(Result, DataSet[0].FeatureVec.FeatureVecLen);

     for featureCnt := 0 to DataSet[0].FeatureVec.FeatureVecLen - 1 do
     begin
          Result[0][0] := DataSet[0].FeatureVec[0];
          Result[0][1] := DataSet[0].FeatureVec[0];
     end;

     for counter := 1 to DataSet.Count - 1 do
     begin
          for featureCnt := 0 to DataSet[0].FeatureVec.FeatureVecLen - 1 do
          begin
               Result[featureCnt][0] := Min(Result[featureCnt][0], DataSet[counter].FeatureVec[featureCnt]);
               Result[featureCnt][1] := Max(Result[featureCnt][1], DataSet[counter].FeatureVec[featureCnt]);
          end;
     end;
end;

class function TNeuralNetLearner.CanLearnClassifier(
  Classifier: TCustomClassifierClass): boolean;
begin
     Result := Classifier = TNeuralNet;
end;

procedure TNeuralNetLearner.UpdateWeightsByLearnRate(deltaK: double;
  outputs: TDoubleDynArray; neuron: TNeuron);
var counter : integer;
begin
     // very simple update rule (simple gradient decent with learning factor eta)
     neuron.fWeights[0] := neuron.fWeights[0] + fProps.eta*deltaK*1;

     if fProps.l1Normalization > 0 then
     begin
          for counter := 1 to Length(neuron.fWeights) - 1 do
          begin
               neuron.fWeights[counter] := neuron.fWeights[counter] + Sign(neuron.fWeights[counter])*fProps.l1Normalization;
               neuron.fWeights[counter] := neuron.fWeights[counter] +
                                           fCurExampleWeight*fProps.eta*deltaK*outputs[counter - 1];
          end;
     end
     else
     begin
          for counter := 1 to Length(neuron.fWeights) - 1 do
              neuron.fWeights[counter] := neuron.fWeights[counter] + fCurExampleWeight*fProps.eta*deltaK*outputs[counter - 1];
     end;
end;


procedure TNeuralNetLearner.UpdateWeightsMomentum(deltaK: double;
  outputs: TDoubleDynArray; neuron: TNeuron);
var counter : integer;
    weightUpdate : TDoubleDynArray;
begin
     SetLength(weightUpdate, Length(neuron.fWeights));
     if neuron.fDeltaWM1 = nil then
        neuron.fDeltaWM1 := weightUpdate;

     // momentum: take the previous weight update into account
     weightUpdate[0] := fProps.eta*deltaK*1 + fProps.alpha*neuron.fDeltaWM1[0];
     for counter := 1 to Length(neuron.fWeights) - 1 do
         weightUpdate[counter] := fProps.eta*deltaK*outputs[counter - 1] + fProps.alpha*neuron.fDeltaWM1[counter];

     for counter := 0 to Length(neuron.fWeights) - 1 do
         neuron.fWeights[counter] := neuron.fWeights[counter] + fCurExampleWeight*weightUpdate[counter];
     neuron.fDeltaWM1 := weightUpdate;
end;


function TNeuralNetLearner.DataSetMeanVar: TNeuralMinMaxArr;
var counter : integer;
    featureCnt : integer;
    aMeanVarMtx : IMatrix;
    aMeanVar : TMeanVarRec;
begin
     SetLength(Result, DataSet[0].FeatureVec.FeatureVecLen);

     if DataSet is TMatrixLearnerExampleList then
     begin
          aMeanVarMtx := (DataSet as TMatrixLearnerExampleList).Matrix.MeanVariance(True);

          for featureCnt := 0 to aMeanVarMtx.Height - 1 do
          begin
               Result[featureCnt][0] := aMeanVarMtx[0, featureCnt];
               Result[featureCnt][1] := sqrt( aMeanVarMtx[1, featureCnt] );
          end;
     end
     else
     begin
          aMeanVarMtx := TDoubleMatrix.Create( DataSet.Count, 1 );
          for featureCnt := 0 to Length(Result) - 1 do
          begin
               for counter := 0 to DataSet.Count - 1 do
                   aMeanVarMtx.Vec[counter] := DataSet[counter].FeatureVec[featureCnt];

               VecMeanVar( aMeanVar, aMeanVarMtx.StartElement, aMeanVarMtx.Width, True);
               Result[featureCnt][0] := aMeanVar.aMean;
               Result[featureCnt][1] := sqrt( aMeanVar.aVar );
          end;
     end;
end;

{ TNeuralNet }

function TNeuralNet.Classify(Example: TCustomExample;
  var confidence: double): integer;
var ok : TDoubleDynArray;
    counter: Integer;
    maxIdx : integer;
begin
     confidence := 0;

     SetLength(ok, Example.FeatureVec.FeatureVecLen);
     // ###########################################
     // #### Restrict input to defined min max
     for counter := 0 to Example.FeatureVec.FeatureVecLen - 1 do
         ok[counter] := Max(Min(Example.FeatureVec[counter], fNet.fInputMinMax[counter][1]), fNet.fInputMinMax[counter][0]);

     ok := fNet.Feed(ok);

     //for layerCnt := 0 to Length(fNet.fLayer) - 1 do
     //s    ok := fNet.fLayer[layerCnt].Feed(ok);
      
     // maximum wins
     maxIdx := 0;
     confidence := ok[0];

     for counter := 0 to Length(ok) - 1 do
         if ok[maxIdx] < ok[counter] then
         begin
              maxIdx := counter;
              confidence := Max(0, ok[counter]);
         end;

     confidence := max(0, Min(1, confidence));
     Result := fClasses[maxIdx];
end;

constructor TNeuralNet.Create(aNet: TFeedForwardNeuralNet; aClassList : TIntegerDynArray);
begin
     fNet := aNet;
     fClasses := aClassList;

     inherited Create;
end;

destructor TNeuralNet.Destroy;
begin
     fNet.Free;

     inherited;
end;

function TNeuralNet.OnLoadObject(const Name: String;
  Obj: TBaseMathPersistence): boolean;
begin
     Result := True;
     if SameText(Name, cNeuralNet)
     then
         fNet := Obj as TFeedForwardNeuralNet
     else
         Result := inherited OnLoadObject(Name, obj);
end;

procedure TNeuralNet.OnLoadIntArr(const Name: String;
  const Value: TIntegerDynArray);
begin
     if SameText(Name, cClassLabels)
     then
         fClasses := Value
     else
         inherited;
end;

procedure TNeuralNet.DefineProps;
begin
     inherited;

     AddIntArr(cClassLabels, fClasses);
     AddObject(cNeuralNet, fNet);
end;

function TNeuralNet.PropTypeOfName(const Name: string): TPropType;
begin
     if CompareText(Name, cClassLabels) = 0
     then
         Result := ptInteger
     else if CompareText(Name, cNeuralNet) = 0
     then
         Result := ptObject
     else
         Result := inherited PropTypeOfName(Name);
end;


initialization
  RegisterMathIO(TNeuralNet);
  RegisterMathIO(TFeedForwardNeuralNet);
  RegisterMathIO(TNeuralLayer);
  RegisterMathIO(TNeuron);


end.
