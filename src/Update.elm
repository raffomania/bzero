module Update exposing (update)

import Date
import Dict
import Model exposing (Model)
import Month
import Msg exposing (..)
import Storage
import Time
import Util exposing (dictUpsert)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ newTransaction } as model) =
    case msg of
        NewTime time ->
            let
                date =
                    Date.fromPosix Time.utc time
            in
            ( { model | date = date }, Cmd.none )

        Msg.SetCurrentMonth time ->
            let
                monthOfYear =
                    { month = Time.toMonth Time.utc time, year = Time.toYear Time.utc time }

                updatedMonth =
                    { model | currentMonth = monthOfYear }

                updatedNewTransactionDate =
                    update (AddTransactionNewDate newTransaction.dayOfMonth) updatedMonth
            in
            updatedNewTransactionDate

        AddTransaction ->
            let
                updatedTransaction =
                    { date = newTransaction.date
                    , value = newTransaction.value
                    , category = newTransaction.category
                    , note = newTransaction.note
                    }

                updatedModel =
                    { model
                        | transactions = updatedTransaction :: model.transactions
                        , newTransaction = { newTransaction | value = 0, note = "" }
                    }
            in
            ( updatedModel
            , Storage.storeModel updatedModel
            )

        AddTransactionNewValue value ->
            ( { model | newTransaction = { newTransaction | value = value } }, Cmd.none )

        AddTransactionNewCategory value ->
            ( { model | newTransaction = { newTransaction | category = value } }, Cmd.none )

        AddTransactionNewDate value ->
            let
                newTransactionDay =
                    value
                        |> String.toInt
                        |> Maybe.withDefault 1

                newTransactionDate =
                    newTransactionDay
                        |> Date.fromCalendarDate model.currentMonth.year model.currentMonth.month
            in
            ( { model | newTransaction = { newTransaction | date = newTransactionDate, dayOfMonth = value } }, Cmd.none )

        AddTransactionNewNote value ->
            ( { model | newTransaction = { newTransaction | note = value } }, Cmd.none )

        ChangeBudgetEntry month category value ->
            let
                monthIndex =
                    Model.getMonthIndex month

                defaultEntry =
                    { value = value, category = category }

                updateMonth =
                    \monthDict ->
                        dictUpsert
                            category
                            (\e -> { e | value = value })
                            defaultEntry
                            monthDict

                months =
                    dictUpsert
                        monthIndex
                        updateMonth
                        (Dict.singleton category defaultEntry)
                        model.budgetEntries

                updatedModel =
                    { model | budgetEntries = months, editingBudgetEntry = Nothing }
            in
            ( updatedModel, Storage.storeModel updatedModel )

        UpdateFromStorage value ->
            case Storage.decodeModel value of
                Ok newModel ->
                    let
                        updatedModel =
                            { model | transactions = newModel.transactions, budgetEntries = newModel.budgetEntries }

                        updatedWithSettings =
                            case newModel.settings of
                                Just settings ->
                                    { updatedModel | settings = settings }

                                _ ->
                                    updatedModel
                    in
                    ( updatedWithSettings, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ChangeTransactionValue transaction value ->
            let
                updateTransaction t =
                    if t == transaction then
                        { t | value = value }

                    else
                        t

                updatedModel =
                    { model | transactions = List.map updateTransaction model.transactions }
            in
            ( updatedModel, Storage.storeModel updatedModel )

        NextMonth ->
            ( { model | currentMonth = Month.increment model.currentMonth }, Cmd.none )

        PreviousMonth ->
            ( { model | currentMonth = Month.decrement model.currentMonth }, Cmd.none )

        RemoveTransaction transaction ->
            let
                updatedTransactions =
                    model.transactions
                        |> List.filter ((/=) transaction)

                updatedModel =
                    { model | transactions = updatedTransactions }
            in
            ( updatedModel, Storage.storeModel updatedModel )

        RemoveBudgetEntry month category ->
            let
                updateMonth =
                    Maybe.map (Dict.remove category)

                updatedEntries =
                    Dict.update (Model.getMonthIndex month)
                        updateMonth
                        model.budgetEntries

                updatedModel =
                    { model | budgetEntries = updatedEntries }
            in
            ( updatedModel, Storage.storeModel updatedModel )

        ChangePage page ->
            ( { model | currentPage = page }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        ChangeCurrencySymbol symbol ->
            let
                settings =
                    model.settings

                updatedSettings =
                    { settings | currencySymbol = symbol }

                updatedModel =
                    { model | settings = updatedSettings }
            in
            ( updatedModel, Storage.storeModel updatedModel )

        ChangeEditedBudgetEntry month category value ->
            let
                default =
                    { category = category
                    , month = month
                    , value = value
                    }

                edit =
                    model.editingBudgetEntry
                        |> Maybe.andThen
                            (\e ->
                                if e.month /= month || e.category /= category then
                                    Nothing

                                else
                                    Just e
                            )
                        |> Maybe.withDefault default

                newEdit =
                    { edit | value = value }
            in
            ( { model | editingBudgetEntry = Just newEdit }, Cmd.none )

        ChangeSyncAddress newAddress ->
            let
                settings =
                    model.settings

                updatedSettings =
                    { settings | syncAddress = newAddress }
            in
            ( { model | settings = updatedSettings }, Cmd.none )

        ConnectRemoteStorage ->
            ( model, Cmd.batch [ Storage.connect model.settings.syncAddress, Storage.storeModel model ] )
